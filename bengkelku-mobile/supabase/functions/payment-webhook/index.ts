// payment-webhook — Supabase Edge Function (Deno)
//
// Menerima webhook Xendit (invoice.paid / invoice.expired / payment.*), memverifikasi
// X-Callback-Token, lalu memperbarui payments + bookings via RPC payment_mark.
// HARUS idempoten: Xendit mengirim ulang webhook, dan payment_mark menolak mengubah
// transaksi yang sudah paid/refunded.
//
// Verifikasi: header `X-Callback-Token` dibandingkan dengan XENDIT_WEBHOOK_TOKEN
// (Verification Token di dashboard Xendit → Settings → Callbacks).
//
// Secret (set via `supabase secrets set`):
//   SUPABASE_URL, SERVICE_ROLE_KEY, XENDIT_WEBHOOK_TOKEN
//
// Deploy: supabase functions deploy payment-webhook --no-verify-jwt
//
// URL webhook daftarkan di dashboard Xendit:
//   https://<project>.functions.supabase.co/payment-webhook
// Centang: invoice.paid, invoice.expired (dan opsional payment.succeeded/failed).

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!, // service role: bypass RLS
);

const WEBHOOK_TOKEN = Deno.env.get("XENDIT_WEBHOOK_TOKEN") ?? "";

// Status invoice Xendit → status internal kita.
// SETTLED & PAID keduanya berarti dana diterima; untuk escrow kita pakai PAID
// (dana baru benar-benar dicairkan ke bengkel saat SELESAI via payout-batch).
const STATUS_MAP: Record<string, "paid" | "expired" | "failed"> = {
  PAID: "paid",
  SETTLED: "paid",
  SUCCEEDED: "paid",
  EXPIRED: "expired",
  VOIDED: "expired",
  CANCELED: "expired",
  FAILED: "failed",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method Not Allowed" });

  // Verifikasi token: Xendit merekomendasikan pengecekan X-Callback-Token.
  const callbackToken = req.headers.get("x-callback-token") ?? "";
  if (!WEBHOOK_TOKEN || callbackToken !== WEBHOOK_TOKEN) {
    console.error("X-Callback-Token tidak valid");
    return json(401, { error: "Invalid callback token" });
  }

  let payload: {
    event?: string;
    data?: {
      // Schema invoice webhook (external_id).
      external_id?: string;
      status?: string;
      payment_method?: string;
      paid_at?: string;
      // Schema Payments-API webhook (reference_id).
      reference_id?: string;
    };
  };
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "Bad Request" });
  }

  const event = payload.event ?? "";
  const data = payload.data ?? {};
  // Cocokkan kedua schema webhook Xendit (invoice.* memakai external_id,
  // payment.* memakai reference_id).
  const providerRef = data.external_id ?? data.reference_id;
  if (!providerRef) {
    console.error("webhook tanpa reference transaksi", event);
    return json(400, { error: "Reference transaksi tidak ditemukan" });
  }

  // Status diambil dari payload; bila kosong, ambil dari nama event.
  let status: "paid" | "expired" | "failed" | undefined =
    STATUS_MAP[data.status?.toUpperCase() ?? ""];
  if (!status) {
    if (event.endsWith(".paid") || event === "payment.succeeded") status = "paid";
    else if (event.endsWith(".expired") || event === "payment.failed") {
      status = event === "payment.failed" ? "failed" : "expired";
    }
  }
  if (!status) {
    console.error("status webhook tidak dikenal", event, data.status);
    return json(200, { ok: true, ignored: true, reason: "status tidak dikenal" });
  }

  const { error } = await supabase.rpc("payment_mark", {
    p_provider_ref: providerRef,
    p_status: status,
    p_method: data.payment_method ?? null,
    p_paid_at: data.paid_at ?? null,
  });

  if (error) {
    console.error("payment_mark gagal", providerRef, error.message);
    // Kembalikan error agar Xendit mengirim ulang (providerRef mungkin belum ada
    // bila webhook tiba sebelum payment_set_invoice selesai).
    return json(500, { error: error.message });
  }

  return json(200, { ok: true });
});
