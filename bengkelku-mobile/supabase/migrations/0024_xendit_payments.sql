-- 0024_xendit_payments.sql — integrasi payment gateway Xendit (PRD FR-P1)
--
-- Sebelumnya pembayaran online hanya jalan di mode sandbox (booking_sandbox_pay).
-- Sekarang alur produksinya:
--   1. Klien minta "payment intent" lewat RPC booking_create_payment (JWT pengendara).
--      Nominal & status dihitung server dari bookings.total_idr — klien tidak bisa
--      memanipulasi angka. Hasilnya baris payments status='pending' provider='xendit'.
--   2. Edge Function xendit-pay membuat invoice di Xendit pakai XENDIT_SECRET_KEY,
--      lalu menyimpan invoice_url + qr_string lewat RPC payment_set_invoice.
--   3. Xendit memanggil webhook → Edge Function payment-webhook (verifikasi
--      X-Callback-Token) → RPC payment_mark → status payments + bookings diperbarui.
--
-- Rahasia (XENDIT_SECRET_KEY, XENDIT_WEBHOOK_TOKEN, SERVICE_ROLE_KEY) HANYA ada
-- di Edge Functions, tidak pernah di aplikasi (ARCHITECTURE.md §3).

-- Kolom hasil invoice gateway supaya klien bisa menampilkan QRIS / tautan bayar
-- tanpa memanggil Xendit untuk kedua kalinya.
alter table public.payments
  add column if not exists invoice_url text,
  add column if not exists qr_string text,
  add column if not exists expires_at timestamptz;

comment on column public.payments.invoice_url is 'Tautan invoice Xendit (hosted checkout)';
comment on column public.payments.qr_string is 'String QRIS untuk dirender jadi QR';
comment on column public.payments.expires_at is 'Kedaluwarsa invoice gateway';

-- Saklar produksi: baru menyala saat admin mendaftarkan Xendit & menutup sandbox.
insert into public.app_config (key, value, label) values
  ('xendit_enabled', 'false'::jsonb, 'Pembayaran online via Xendit aktif (produksi)')
on conflict (key) do nothing;

-- booking_create_payment(booking, method)
-- Buat (atau kembalikan) baris payments pending untuk Xendit. Idempoten: ulang
-- panggilan untuk booking yang sama mengembalikan intent yang sudah ada, sehingga
-- tombol "bayar" yang ditekan berkali-kali tidak membuat invoice ganda.
create or replace function public.booking_create_payment(p_booking_id uuid, p_method text default 'qris')
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_b public.bookings;
  v_pay public.payments;
  v_method text := coalesce(nullif(trim(p_method), ''), 'qris');
  v_pay_min int := coalesce((public.app_config_value('booking_payment_minutes') #>> '{}')::int, 60);
begin
  if v_method not in ('qris', 'ewallet', 'va') then
    raise exception 'Metode pembayaran tidak didukung';
  end if;
  if coalesce((public.app_config_value('xendit_enabled') #>> '{}')::boolean, false) is not true then
    raise exception 'Pembayaran online sedang tidak tersedia';
  end if;

  select * into v_b from public.bookings where id = p_booking_id for update;
  if v_b.id is null or v_b.rider_id <> auth.uid() then
    raise exception 'Booking tidak ditemukan';
  end if;

  -- Batas bayar lewat → kedaluwarsakan dulu sebelum menolak.
  if v_b.status = 'MENUNGGU_PEMBAYARAN' and v_b.payment_deadline is not null
     and v_b.payment_deadline < now() then
    update public.bookings set status = 'KEDALUWARSA', updated_at = now()
    where id = p_booking_id;
    raise exception 'Batas waktu pembayaran sudah lewat, silakan pesan ulang jadwal';
  end if;
  if v_b.status <> 'MENUNGGU_PEMBAYARAN' then
    raise exception 'Booking ini tidak menunggu pembayaran (status: %)', v_b.status;
  end if;

  -- Ambil intent Xendit pending yang lama (belum dipakai), bila ada.
  select * into v_pay
  from public.payments
  where booking_id = p_booking_id and provider = 'xendit' and status = 'pending'
  order by created_at desc
  limit 1;

  if v_pay.id is null then
    insert into public.payments (booking_id, provider, provider_ref, method, amount_idr, status, expires_at)
    values (p_booking_id, 'xendit', 'bk-' || replace(v_b.id::text, '-', ''),
            v_method, v_b.total_idr, 'pending',
            coalesce(v_b.payment_deadline, now() + make_interval(mins => v_pay_min)))
    returning * into v_pay;
  end if;

  return jsonb_build_object(
    'payment_id', v_pay.id,
    'provider_ref', v_pay.provider_ref,
    'amount_idr', v_pay.amount_idr,
    'method', v_pay.method,
    'expires_at', v_pay.expires_at,
    'invoice_url', v_pay.invoice_url,
    'qr_string', v_pay.qr_string
  );
end$$;

-- payment_set_invoice(provider_ref, url, qr, expires_at)
-- Menyimpan hasil create-invoice Xendit. Hanya untuk service role (Edge Function).
-- Boleh gagal tanpa membahayakan alur: webhook tetap cocok berdasarkan provider_ref.
create or replace function public.payment_set_invoice(
  p_provider_ref text, p_invoice_url text,
  p_qr_string text default null, p_expires_at timestamptz default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_pay public.payments;
begin
  select * into v_pay from public.payments where provider_ref = p_provider_ref for update;
  if v_pay.id is null then raise exception 'Payment tidak ditemukan'; end if;
  if v_pay.status <> 'pending' then
    -- Sudah lunas/kedaluwarsa: jangan timpa data transaksi yang sudah final.
    return jsonb_build_object('payment_id', v_pay.id, 'status', v_pay.status, 'updated', false);
  end if;

  update public.payments
  set invoice_url = p_invoice_url,
      qr_string = coalesce(p_qr_string, qr_string),
      expires_at = coalesce(p_expires_at, expires_at)
  where id = v_pay.id
  returning * into v_pay;

  return jsonb_build_object('payment_id', v_pay.id, 'status', v_pay.status, 'updated', true);
end$$;

-- payment_mark(provider_ref, status, method, paid_at)
-- Dipanggil webhook Xendit setelah verifikasi X-Callback-Token. Status transisi:
--   paid    → payments.paid  + booking.DIBAYAR_MENUNGGU_KONFIRMASI + notif owner
--   expired → payments.expired + booking.KEDALUWARSA
--   failed  → payments.failed, booking tetap MENUNGGU_PEMBAYARAN (pengendara bisa coba lagi)
-- Idempoten: transaksi yang sudah paid/refunded tidak pernah diubah ulang.
-- Trigger trg_booking_paid_chat membuat thread chat otomatis saat booking lunas.
create or replace function public.payment_mark(
  p_provider_ref text, p_status text, p_method text default null, p_paid_at timestamptz default null
)
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_pay public.payments;
  v_b public.bookings;
  v_pay_status payment_status;
  v_booking_status booking_status;
  v_owner uuid;
begin
  if p_status not in ('paid', 'expired', 'failed') then
    raise exception 'Status webhook tidak valid: %', p_status;
  end if;

  select * into v_pay from public.payments where provider_ref = p_provider_ref for update;
  if v_pay.id is null then raise exception 'Payment tidak ditemukan: %', p_provider_ref; end if;

  -- Pengiriman ulang webhook tidak menggandakan efek.
  if v_pay.status in ('paid', 'refunded') then
    return jsonb_build_object('ok', true, 'idempotent', true,
      'payment_id', v_pay.id, 'status', v_pay.status);
  end if;

  v_pay_status := p_status::payment_status;
  update public.payments
  set status = v_pay_status,
      method = coalesce(nullif(trim(p_method), ''), method),
      paid_at = case when p_status = 'paid' then coalesce(p_paid_at, now()) else null end
  where id = v_pay.id
  returning * into v_pay;

  select * into v_b from public.bookings where id = v_pay.booking_id for update;
  if v_b.id is null then
    return jsonb_build_object('ok', true, 'payment_id', v_pay.id, 'status', v_pay.status);
  end if;

  v_booking_status := case p_status
    when 'paid' then 'DIBAYAR_MENUNGGU_KONFIRMASI'
    when 'expired' then 'KEDALUWARSA'
    else 'MENUNGGU_PEMBAYARAN'
  end;

  if v_b.status = 'MENUNGGU_PEMBAYARAN' and v_booking_status <> 'MENUNGGU_PEMBAYARAN' then
    update public.bookings set status = v_booking_status, updated_at = now()
    where id = v_b.id returning * into v_b;
  end if;

  if p_status = 'paid' then
    select owner_id into v_owner from public.workshops where id = v_b.workshop_id;
    insert into public.notifications (user_id, kind, title, body, data)
    values (v_owner, 'booking', 'booking baru menunggu konfirmasi',
            to_char(v_b.scheduled_at at time zone 'Asia/Jakarta', 'DD Mon HH24:MI') || ' · Rp' ||
              to_char(v_b.total_idr, 'FM999G999G999'),
            jsonb_build_object('booking_id', v_b.id, 'route', '/owner'));
  end if;

  return jsonb_build_object('ok', true, 'payment_id', v_pay.id,
    'status', v_pay.status, 'booking_status', v_b.status);
end$$;

grant execute on function public.booking_create_payment(uuid, text) to authenticated;
revoke execute on function public.payment_set_invoice(text, text, text, timestamptz)
  from public, anon, authenticated;
revoke execute on function public.payment_mark(text, text, text, timestamptz)
  from public, anon, authenticated;
