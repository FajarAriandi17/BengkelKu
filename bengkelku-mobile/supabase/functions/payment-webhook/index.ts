// payment-webhook — Supabase Edge Function (Deno)
//
// Menerima webhook dari gateway (Midtrans/Xendit), memverifikasi tanda tangan,
// lalu memperbarui tabel `payments` + `bookings`. HARUS idempoten: pakai
// `provider_ref` sebagai kunci unik sehingga pengiriman ganda tidak menggandakan efek.
//
// Secret (set via `supabase secrets set`):
//   SUPABASE_URL, SERVICE_ROLE_KEY, PAYMENT_WEBHOOK_SECRET
//
// Deploy: supabase functions deploy payment-webhook --no-verify-jwt

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!, // service role: bypass RLS
);

const WEBHOOK_SECRET = Deno.env.get("PAYMENT_WEBHOOK_SECRET") ?? "";

interface WebhookPayload {
  provider_ref: string; // id transaksi gateway (unik)
  booking_id: string;
  status: "paid" | "failed" | "expired";
  method?: string;
  amount_idr: number;
  signature?: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  let body: WebhookPayload;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  // Verifikasi tanda tangan sederhana (ganti sesuai gateway nyata).
  if (WEBHOOK_SECRET && body.signature !== WEBHOOK_SECRET) {
    return new Response("Invalid signature", { status: 401 });
  }

  // Idempoten: jika payment dengan provider_ref ini sudah 'paid', hentikan.
  const { data: existing } = await supabase
    .from("payments")
    .select("id,status")
    .eq("provider_ref", body.provider_ref)
    .maybeSingle();

  if (existing?.status === "paid") {
    return new Response(JSON.stringify({ ok: true, idempotent: true }), {
      headers: { "content-type": "application/json" },
    });
  }

  // Upsert payment berdasarkan provider_ref.
  const paymentStatus = body.status === "paid"
    ? "paid"
    : body.status === "expired"
    ? "expired"
    : "failed";

  await supabase.from("payments").upsert({
    provider_ref: body.provider_ref,
    booking_id: body.booking_id,
    method: body.method ?? null,
    amount_idr: body.amount_idr,
    status: paymentStatus,
    paid_at: body.status === "paid" ? new Date().toISOString() : null,
  }, { onConflict: "provider_ref" });

  // Perbarui status booking sesuai hasil pembayaran.
  const bookingStatus = body.status === "paid"
    ? "DIBAYAR_MENUNGGU_KONFIRMASI"
    : body.status === "expired"
    ? "KEDALUWARSA"
    : "MENUNGGU_PEMBAYARAN";

  await supabase
    .from("bookings")
    .update({ status: bookingStatus, updated_at: new Date().toISOString() })
    .eq("id", body.booking_id);

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" },
  });
});
