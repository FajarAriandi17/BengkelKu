// xendit-pay — Supabase Edge Function (Deno)
//
// Membuat invoice Xendit untuk booking yang menunggu pembayaran. Dipanggil
// aplikasi dengan JWT pengendara (header Authorization, diatur otomatis oleh
// supabase_flutter lewat functions.invoke).
//
// Alur (nominal tidak pernah ditentukan klien):
//   1. RPC booking_create_payment memvalidasi kepemilikan (auth.uid()), status
//      booking, dan batas pembayaran, lalu menyisipkan baris payments pending
//      dengan nominal dari bookings.total_idr.
//   2. Bila invoice sudah pernah dibuat (invoice_url terisi), kembalikan apa
//      adanya — ini yang membuat panggilan ulang tidak membuat invoice ganda.
//   3. POST /v2/invoices ke Xendit memakai XENDIT_SECRET_KEY (Basic auth).
//   4. payment_set_invoice menyimpan invoice_url + qr_string (service role).
//
// Secret (set via `supabase secrets set`):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SERVICE_ROLE_KEY, XENDIT_SECRET_KEY
//   XENDIT_API_BASE opsional (default https://api.xendit.co) untuk test mode.
//
// Deploy: supabase functions deploy xendit-pay

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const XENDIT_SECRET_KEY = Deno.env.get("XENDIT_SECRET_KEY") ?? "";
const XENDIT_API = Deno.env.get("XENDIT_API_BASE") ?? "https://api.xendit.co";

// Metode pembayaran Xendit per kategori (lihat XENDIT_PAYMENT_CHANNELS).
// QRIS menampilkan QR; e-wallet & VA diarahkan ke invoice_url (hosted checkout).
const PAYMENT_CHANNELS: Record<string, string[]> = {
  qris: ["QRIS"],
  ewallet: ["GOPAY", "OVO", "DANA", "SHOPEEPAY", "LINKAJA"],
  va: ["BCA", "BNI", "BRI", "MANDIRI", "PERMATA"],
};

interface PaymentIntent {
  payment_id: string;
  provider_ref: string;
  amount_idr: number;
  method: string;
  expires_at: string | null;
  invoice_url: string | null;
  qr_string: string | null;
}

interface InvoiceResponse {
  id: string;
  external_id: string;
  status: string;
  amount: number;
  invoice_url: string;
  expiry_date?: string;
  qr_string?: string;
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method Not Allowed" });
  if (!XENDIT_SECRET_KEY) {
    console.error("XENDIT_SECRET_KEY belum diset");
    return json(500, { error: "Server pembayaran belum dikonfigurasi" });
  }

  // JWT pengendara dipakai untuk memanggil RPC → auth.uid() memvalidasi kepemilikan.
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) return json(401, { error: "Silakan masuk terlebih dahulu" });

  let body: { booking_id?: string; method?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Body permintaan tidak valid" });
  }
  const bookingId = body.booking_id;
  const method = body.method ?? "qris";
  if (!bookingId) return json(400, { error: "booking_id wajib diisi" });

  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: intentData, error: intentErr } = await asUser.rpc(
    "booking_create_payment",
    { p_booking_id: bookingId, p_method: method },
  );
  if (intentErr || !intentData) {
    return json(400, { error: intentErr?.message ?? "Gagal memulai pembayaran" });
  }
  const intent = intentData as unknown as PaymentIntent;

  // Idempoten: invoice sudah dibuat sebelumnya → pakai lagi.
  if (intent.invoice_url) {
    return json(200, { ...intent, reused: true });
  }

  // Durasi invoice = sisa batas pembayaran booking (minimal 60 detik).
  const expiresMs = intent.expires_at ? Date.parse(intent.expires_at) : Date.now() + 60_000;
  const invoiceDuration = Math.max(60, Math.round((expiresMs - Date.now()) / 1000));
  const channels = PAYMENT_CHANNELS[intent.method] ?? PAYMENT_CHANNELS.qris;

  let inv: InvoiceResponse;
  try {
    const res = await fetch(`${XENDIT_API}/v2/invoices`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Basic ${btoa(`${XENDIT_SECRET_KEY}:`)}`,
      },
      body: JSON.stringify({
        external_id: intent.provider_ref,
        amount: intent.amount_idr,
        currency: "IDR",
        description: `Pembayaran booking BengkelKu ${intent.provider_ref}`,
        invoice_duration: invoiceDuration,
        payment_methods: channels,
        locale: "id",
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error("xendit invoice gagal", res.status, detail);
      // Jangan bocorkan detail gateway ke klien; cukup kode & status.
      return json(res.status, {
        error: "Gagal membuat invoice pembayaran, silakan coba lagi",
        xendit_status: res.status,
      });
    }
    inv = (await res.json()) as InvoiceResponse;
  } catch (e) {
    console.error("xendit unreachable", e);
    return json(502, { error: "Layanan pembayaran tidak dapat dihubungi" });
  }

  // Simpan invoice ke DB. Kegagalan di sini tidak fatal: webhook tetap jalan
  // mencocokkan provider_ref, dan pengguna bisa membuka ulang layar ini.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  await admin.rpc("payment_set_invoice", {
    p_provider_ref: intent.provider_ref,
    p_invoice_url: inv.invoice_url,
    p_qr_string: inv.qr_string ?? null,
    p_expires_at: inv.expiry_date ?? null,
  });

  return json(200, {
    payment_id: intent.payment_id,
    provider_ref: intent.provider_ref,
    amount_idr: intent.amount_idr,
    method: intent.method,
    expires_at: inv.expiry_date ?? intent.expires_at,
    invoice_url: inv.invoice_url,
    qr_string: inv.qr_string ?? null,
    xendit_invoice_id: inv.id,
    reused: false,
  });
});
