-- 0025_mayar_payments.sql — integrasi payment gateway Mayar.id (PRD FR-P1)
--
-- Menggantikan 0024 (Xendit). Alur produksinya:
--   1. Klien minta intent lewat RPC booking_create_payment (JWT pengendara). Nominal & status
--      dihitung server dari bookings.total_idr — klien tidak bisa memanipulasi angka. Hasilnya
--      baris payments status='pending' provider='mayar', plus data customer + items untuk membuat
--      invoice Mayar (satu round trip).
--   2. Edge Function mayar-pay POST /hl/v2/invoices/create (Bearer MAYAR_API_KEY), lalu menyimpan
--      link + transactionId + expiredAt lewat RPC payment_set_invoice.
--   3. Mayar memanggil webhook → Edge Function payment-webhook (verifikasi token di query string) →
--      RPC payment_mark → status payments + bookings diperbarui. Lookup webhook dilakukan via
--      gateway_txn_id (transactionId Mayar), BUKAN provider_ref, karena webhook Mayar hanya
--      membawa transactionId.
--
-- Rahasia (MAYAR_API_KEY, MAYAR_WEBHOOK_SECRET, SERVICE_ROLE_KEY) HANYA ada di Edge Functions,
-- tidak pernah di aplikasi (ARCHITECTURE.md §3).

-- Kolom hasil invoice gateway. gateway_txn_id = transactionId Mayar — kunci lookup webhook.
alter table public.payments
  add column if not exists gateway_txn_id text;

-- qr_string tidak dipakai lagi: invoice Mayar tidak mengembalikan QR string (checkout di-hosted
-- page). Hapus agar tidak ada kolom yang menyesatkan.
alter table public.payments drop column if exists qr_string;

comment on column public.payments.invoice_url is 'Tautan invoice Mayar (hosted checkout)';
comment on column public.payments.gateway_txn_id is 'Transaction ID Mayar — kunci lookup webhook';

create unique index if not exists idx_payments_gateway_txn_id
  on public.payments (gateway_txn_id) where gateway_txn_id is not null;

-- Saklar produksi: baru menyala saat admin mendaftarkan Mayar & menutup sandbox.
insert into public.app_config (key, value, label) values
  ('mayar_enabled', 'false'::jsonb, 'Pembayaran online via Mayar aktif (produksi)')
on conflict (key) do nothing;

-- Ganti seluruh RPC versi Xendit (0024).
drop function if exists public.booking_create_payment(uuid, text);
drop function if exists public.payment_set_invoice(text, text, text, timestamptz);
drop function if exists public.payment_mark(text, text, text, timestamptz);

-- booking_create_payment(booking)
-- Buat (atau kembalikan) baris payments pending untuk Mayar. Idempoten: ulang panggilan untuk
-- booking yang sama mengembalikan intent yang sudah ada, sehingga tombol "bayar" yang ditekan
-- berkali-kali tidak membuat invoice ganda.
--
-- Parameter method dihapus: pemilihan kanal (QRIS/e-wallet/VA/retail) dilakukan di halaman hosted
-- checkout Mayar, dan kanal aktual dicatat dari payload webhook. Selain intent, RPC juga
-- mengembalikan data customer + items supaya Edge Function tidak perlu round trip kedua — email
-- hanya ada di auth.users sehingga harus dibaca di sisi server (security definer).
create or replace function public.booking_create_payment(p_booking_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_b public.bookings;
  v_pay public.payments;
  v_customer record;
  v_items jsonb;
  v_pay_min int := coalesce((public.app_config_value('booking_payment_minutes') #>> '{}')::int, 60);
begin
  if coalesce((public.app_config_value('mayar_enabled') #>> '{}')::boolean, false) is not true then
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

  -- Ambil intent Mayar pending yang lama (belum dipakai), bila ada.
  select * into v_pay
  from public.payments
  where booking_id = p_booking_id and provider = 'mayar' and status = 'pending'
  order by created_at desc
  limit 1;

  if v_pay.id is null then
    insert into public.payments (booking_id, provider, provider_ref, amount_idr, status, expires_at)
    values (p_booking_id, 'mayar', 'bk-' || replace(v_b.id::text, '-', ''),
            v_b.total_idr, 'pending',
            coalesce(v_b.payment_deadline, now() + make_interval(mins => v_pay_min)))
    returning * into v_pay;
  end if;

  -- Data invoice Mayar: customer (email hanya ada di auth.users) + item layanan.
  select u.full_name as name, au.email as email, u.phone as mobile, w.name as workshop_name
  into v_customer
  from public.users u
  join auth.users au on au.id = u.id
  join public.workshops w on w.id = v_b.workshop_id
  where u.id = v_b.rider_id;

  select coalesce(jsonb_agg(jsonb_build_object(
           'name', i.name, 'price_idr', i.price_idr, 'quantity', 1
         ) order by i.created_at), '[]'::jsonb)
  into v_items
  from public.booking_items i
  where i.booking_id = p_booking_id and i.price_idr > 0;

  return jsonb_build_object(
    'payment_id', v_pay.id,
    'provider_ref', v_pay.provider_ref,
    'amount_idr', v_pay.amount_idr,
    'method', v_pay.method,
    'expires_at', v_pay.expires_at,
    'invoice_url', v_pay.invoice_url,
    'gateway_txn_id', v_pay.gateway_txn_id,
    'subtotal_idr', v_b.subtotal_idr,
    'service_fee', v_b.total_idr - v_b.subtotal_idr,
    'customer', jsonb_build_object(
      'name', v_customer.name,
      'email', v_customer.email,
      'mobile', v_customer.mobile
    ),
    'workshop_name', v_customer.workshop_name,
    'scheduled_at', v_b.scheduled_at,
    'items', v_items
  );
end$$;

-- payment_set_invoice(provider_ref, url, gateway_txn_id, expires_at)
-- Menyimpan hasil create-invoice Mayar. Hanya untuk service role (Edge Function).
-- Boleh gagal tanpa membahayakan alur: webhook tetap cocok berdasarkan gateway_txn_id.
create or replace function public.payment_set_invoice(
  p_provider_ref text, p_invoice_url text,
  p_gateway_txn_id text default null, p_expires_at timestamptz default null
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
      gateway_txn_id = coalesce(p_gateway_txn_id, gateway_txn_id),
      expires_at = coalesce(p_expires_at, expires_at)
  where id = v_pay.id
  returning * into v_pay;

  return jsonb_build_object('payment_id', v_pay.id, 'status', v_pay.status, 'updated', true);
end$$;

-- payment_mark(gateway_txn_id, status, method, amount, paid_at)
-- Dipanggil webhook Mayar setelah verifikasi token. Lookup via gateway_txn_id (transactionId Mayar).
-- Status transisi:
--   paid    → payments.paid  + booking.DIBAYAR_MENUNGGU_KONFIRMASI + notif owner
--   expired → payments.expired + booking.KEDALUWARSA
--   failed  → payments.failed, booking tetap MENUNGGU_PEMBAYARAN (pengendara bisa coba lagi)
-- Idempoten: transaksi yang sudah paid/refunded tidak pernah diubah ulang.
-- Nominal webhook divalidasi terhadap amount_idr yang ditetapkan server (anti pemalsuan).
-- Trigger trg_booking_paid_chat membuat thread chat otomatis saat booking lunas.
create or replace function public.payment_mark(
  p_gateway_txn_id text, p_status text, p_method text default null,
  p_amount int default null, p_paid_at timestamptz default null
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

  select * into v_pay from public.payments where gateway_txn_id = p_gateway_txn_id for update;
  if v_pay.id is null then raise exception 'Payment tidak ditemukan: %', p_gateway_txn_id; end if;

  -- Pengiriman ulang webhook tidak menggandakan efek.
  if v_pay.status in ('paid', 'refunded') then
    return jsonb_build_object('ok', true, 'idempotent', true,
      'payment_id', v_pay.id, 'status', v_pay.status);
  end if;

  -- Nominal webhook harus cocok dengan nominal yang ditetapkan server.
  if p_amount is not null and p_amount <> v_pay.amount_idr then
    raise exception 'Nominal webhook (%) tidak cocok dengan tagihan (%)', p_amount, v_pay.amount_idr;
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

grant execute on function public.booking_create_payment(uuid) to authenticated;
revoke execute on function public.payment_set_invoice(text, text, text, timestamptz)
  from public, anon, authenticated;
revoke execute on function public.payment_mark(text, text, text, int, timestamptz)
  from public, anon, authenticated;
