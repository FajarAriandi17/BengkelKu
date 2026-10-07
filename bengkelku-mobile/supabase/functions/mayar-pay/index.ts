// mayar-pay — Supabase Edge Function (Deno)
//
// Membuat invoice Mayar untuk booking yang menunggu pembayaran. Dipanggil aplikasi
// dengan JWT pengendara (header Authorization, diatur otomatis oleh supabase_flutter
// lewat functions.invoke).
//
// Alur (nominal tidak pernah ditentukan klien):
//   1. RPC booking_create_payment memvalidasi kepemilikan (auth.uid()), status booking,
//      dan batas pembayaran, lalu menyisipkan baris payments pending dengan nominal dari
//      bookings.total_idr, plus data customer + item untuk invoice.
//   2. Bila invoice sudah pernah dibuat (invoice_url terisi), kembalikan apa adanya —
//      ini yang membuat panggilan ulang tidak membuat invoice ganda.
//   3. POST /hl/v2/invoices/create ke Mayar memakai MAYAR_API_KEY (Bearer auth).
//   4. payment_set_invoice menyimpan link + transactionId (service role).
//
// Pemilihan kanal (QRIS/e-wallet/VA/retail) TIDAK dikirim ke Mayar — halaman hosted
// checkout-nya yang menampilkan semua kanal aktif, dan kanal aktual tercatat dari
// payload webhook.
//
// Secret (set via `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SERVICE_ROLE_KEY, MAYAR_API_KEY
//   MAYAR_API_BASE opsional (default https://api.mayar.id/hl/v2; sandbox
//   https://api.mayar.io/hl/v2).
//
// Deploy: supabase functions deploy mayar-pay

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const MAYAR_API_KEY = Deno.env.get("MAYAR_API_KEY") ?? "";
const MAYAR_API = Deno.env.get("MAYAR_API_BASE") ?? "https://api.mayar.id/hl/v2";

interface InvoiceItem {
  quantity: number;
  rate: number;
  description: string;
}

interface PaymentIntent {
  payment_id: string;
  provider_ref: string;
  amount_idr: number;
  subtotal_idr: number;
  service_fee: number;
  method: string | null;
  expires_at: string | null;
  invoice_url: string | null;
  gateway_txn_id: string | null;
  customer: { name: string | null; email: string | null; mobile: string | null };
  workshop_name: string | null;
  items: { name: string; price_idr: number; quantity: number }[];
}

interface InvoiceResponse {
  id: string;
  transactionId: string;
  link: string;
  expiredAt?: number;
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method Not Allowed" });
  if (!MAYAR_API_KEY) {
    console.error("MAYAR_API_KEY belum diset");
    return json(500, { error: "Server pembayaran belum dikonfigurasi" });
  }

  // JWT pengendara dipakai untuk memanggil RPC → auth.uid() memvalidasi kepemilikan.
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return json(401, { error: "Silakan masuk terlebih dahulu" });

  let body: { booking_id?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Body permintaan tidak valid" });
  }
  const bookingId = body.booking_id;
  if (!bookingId) return json(400, { error: "booking_id wajib diisi" });

  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: intentData, error: intentErr } = await asUser.rpc(
    "booking_create_payment",
    { p_booking_id: bookingId },
  );
  if (intentErr || !intentData) {
    return json(400, { error: intentErr?.message ?? "Gagal memulai pembayaran" });
  }
  const intent = intentData as unknown as PaymentIntent;

  // Idempoten: invoice sudah dibuat sebelumnya → pakai lagi.
  if (intent.invoice_url) {
    return json(200, {
      payment_id: intent.payment_id,
      provider_ref: intent.provider_ref,
      amount_idr: intent.amount_idr,
      method: intent.method,
      expires_at: intent.expires_at,
      invoice_url: intent.invoice_url,
      gateway_txn_id: intent.gateway_txn_id,
      reused: true,
    });
  }

  // Mayar menghitung total invoice sendiri dari Σ(rate×quantity). Karena setting biaya
  // admin/channel Mayar tidak berlaku untuk Invoice API, biaya layanan platform harus
  // jadi line item eksplisit agar nominal yang ditagih = bookings.total_idr.
  const items: InvoiceItem[] = intent.items.map((i) => ({
    quantity: i.quantity,
    rate: i.price_idr,
    description: i.name,
  }));
  if (intent.service_fee > 0) {
    items.push({ quantity: 1, rate: intent.service_fee, description: "Biaya layanan" });
  }

  // Kedaluwarsa invoice = sisa batas pembayaran booking. Mayar butuh ISO 8601 UTC.
  const expiresMs = intent.expires_at ? Date.parse(intent.expires_at) : NaN;
  const expiredAt = Number.isFinite(expiresMs)
    ? new Date(expiresMs).toISOString()
    : undefined;

  // Nomor HP wajib di Mayar. Bila profil rider kosong, pakai placeholder — invoice tetap
  // jalan, hanya notifikasi WhatsApp/SMS yang tidak sampai (log peringatan).
  const mobile = intent.customer.mobile?.trim() || "620000000000";
  if (!intent.customer.mobile?.trim()) {
    console.warn("rider tanpa no HP, pakai placeholder Mayar", bookingId);
  }

  let inv: InvoiceResponse;
  try {
    const res = await fetch(`${MAYAR_API}/invoices/create`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${MAYAR_API_KEY}`,
      },
      body: JSON.stringify({
        name: intent.customer.name?.trim() || "Pelanggan BengkelKu",
        email: intent.customer.email ?? "pelanggan@bengkelku.app",
        mobile,
        description: `Pembayaran booking BengkelKu ${intent.provider_ref}`,
        items,
        expiredAt,
        extraData: { provider_ref: intent.provider_ref },
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error("mayar invoice gagal", res.status, detail);
      if (res.status === 429) {
        // Mayar menolak duplikat dalam 1 menit.
        return json(429, { error: "Tunggu sebentar, lalu coba bayar lagi" });
      }
      // Jangan bocorkan detail gateway ke klien; cukup kode & status.
      return json(res.status, {
        error: "Gagal membuat invoice pembayaran, silakan coba lagi",
        mayar_status: res.status,
      });
    }
    inv = (await res.json()).data as InvoiceResponse;
  } catch (e) {
    console.error("mayar unreachable", e);
    return json(502, { error: "Layanan pembayaran tidak dapat dihubungi" });
  }

  // Simpan invoice ke DB. Kegagalan di sini tidak fatal: webhook tetap jalan
  // mencocokkan gateway_txn_id, dan pengguna bisa membuka ulang layar ini.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  await admin.rpc("payment_set_invoice", {
    p_provider_ref: intent.provider_ref,
    p_invoice_url: inv.link,
    p_gateway_txn_id: inv.transactionId,
    p_expires_at: inv.expiredAt ? new Date(inv.expiredAt).toISOString() : null,
  });

  return json(200, {
    payment_id: intent.payment_id,
    provider_ref: intent.provider_ref,
    amount_idr: intent.amount_idr,
    method: intent.method,
    expires_at: inv.expiredAt
      ? new Date(inv.expiredAt).toISOString()
      : intent.expires_at,
    invoice_url: inv.link,
    gateway_txn_id: inv.transactionId,
    mayar_invoice_id: inv.id,
    reused: false,
  });
});
