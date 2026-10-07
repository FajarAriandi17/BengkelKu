// payment-webhook — Supabase Edge Function (Deno)
//
// Menerima webhook Mayar (event payment.received), memverifikasi token, lalu
// memperbarui payments + bookings via RPC payment_mark. HARUS idempoten: Mayar
// mengirim ulang webhook, dan payment_mark menolak mengubah transaksi yang sudah
// paid/refunded.
//
// Verifikasi (Mayar tidak mengirim signature header, jadi berlapis):
//   1. Query param `token` pada URL webhook harus sama dengan MAYAR_WEBHOOK_SECRET.
//      URL webhook didaftarkan di dashboard Mayar (Integration → Webhook) sebagai:
//        https://<project-ref>.functions.supabase.co/payment-webhook?token=<secret>
//   2. Bila MAYAR_MERCHANT_ID diset, data.merchantId harus cocok (lapisan kedua).
//   3. RPC payment_mark memvalidasi kecocokan nominal (data.amount vs amount_idr).
//
// Payload webhook Mayar:
//   { event: "payment.received",
//     data: { id, transactionId, status (boolean: true=lunas), amount, paymentMethod,
//             merchantId, customerName, ... } }
//
// Lookup transaksi via data.transactionId (disimpan sebagai payments.gateway_txn_id
// oleh mayar-pay). Event lain (payment.reminder, membership.*) diabaikan.
//
// Secret (set via `supabase secrets set`):
//   SUPABASE_URL, SERVICE_ROLE_KEY, MAYAR_WEBHOOK_SECRET, MAYAR_MERCHANT_ID (opsional)
//
// Deploy: supabase functions deploy payment-webhook --no-verify-jwt
// --no-verify-jwt wajib: Mayar tidak membawa JWT Supabase; keamanan dijamin token di atas.

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!, // service role: bypass RLS
);

const WEBHOOK_SECRET = Deno.env.get("MAYAR_WEBHOOK_SECRET") ?? "";
const MERCHANT_ID = Deno.env.get("MAYAR_MERCHANT_ID") ?? "";

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method Not Allowed" });

  // Lapisan 1: token rahasia di query string (bagian dari URL webhook terdaftar).
  const url = new URL(req.url);
  const token = url.searchParams.get("token") ?? "";
  if (!WEBHOOK_SECRET || token !== WEBHOOK_SECRET) {
    console.error("token webhook tidak valid");
    return json(401, { error: "Invalid webhook token" });
  }

  let payload: {
    event?: string;
    data?: {
      transactionId?: string;
      status?: boolean;
      amount?: number;
      paymentMethod?: string;
      merchantId?: string;
    };
  };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "Bad Request" });
  }

  const event = payload.event ?? "";
  const data = payload.data ?? {};

  // Hanya payment.received yang memicu perubahan status. Event lain (pengingat,
  // membership) tidak relevan untuk booking — balas 200 agar Mayar tidak mengulang.
  if (event !== "payment.received") {
    return json(200, { ok: true, ignored: true, reason: `event ${event} diabaikan` });
  }

  const txnId = data.transactionId;
  if (!txnId) {
    console.error("webhook tanpa transactionId", event);
    return json(400, { error: "Transaction tidak ditemukan" });
  }

  // Lapisan 2: merchant ID harus cocok bila dikonfigurasi.
  if (MERCHANT_ID && data.merchantId && data.merchantId !== MERCHANT_ID) {
    console.error("merchantId tidak cocok", data.merchantId);
    return json(401, { error: "Invalid merchant" });
  }

  // data.status true → lunas; false/absen → gagal (pengendara bisa coba lagi).
  const status: "paid" | "failed" = data.status === true ? "paid" : "failed";

  const { error } = await supabase.rpc("payment_mark", {
    p_gateway_txn_id: txnId,
    p_status: status,
    p_method: data.paymentMethod ?? null,
    p_amount: typeof data.amount === "number" ? data.amount : null,
    p_paid_at: null, // Mayar tidak mengirim paid_at; RPC pakai now().
  });

  if (error) {
    console.error("payment_mark gagal", txnId, error.message);
    // Kembalikan error agar Mayar mengirim ulang — gateway_txn_id mungkin belum
    // tersimpan bila webhook tiba sebelum payment_set_invoice selesai (race).
    return json(500, { error: error.message });
  }

  return json(200, { ok: true });
});
