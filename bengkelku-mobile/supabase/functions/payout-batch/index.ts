// payout-batch — Supabase Edge Function (Deno)
//
// Dijalankan harian (cron). Mengambil booking berstatus SELESAI dari H-1,
// memotong komisi platform (default 8%), membuat baris `payouts`, lalu
// (secara nyata) memicu disbursement ke rekening bengkel via gateway.
// Setelah payout dibuat, booking dipindah ke status PAYOUT.
//
// AMAN DIULANG: lewati booking yang sudah punya payout.
// Secret: SUPABASE_URL, SERVICE_ROLE_KEY, COMMISSION_RATE (opsional)

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!,
);

const COMMISSION_RATE = Number(Deno.env.get("COMMISSION_RATE") ?? "0.08");

Deno.serve(async () => {
  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  // Booking SELESAI yang belum di-payout.
  const { data: bookings, error } = await supabase
    .from("bookings")
    .select("id, workshop_id, total_idr, commission_rate")
    .eq("status", "SELESAI");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let created = 0;

  for (const b of bookings ?? []) {
    // Idempoten: lewati bila sudah ada payout untuk booking ini.
    const { data: existing } = await supabase
      .from("payouts")
      .select("id")
      .eq("booking_id", b.id)
      .maybeSingle();
    if (existing) continue;

    const rate = b.commission_rate ?? COMMISSION_RATE;
    const gross = b.total_idr;
    const commission = Math.round(gross * rate);
    const net = gross - commission;

    await supabase.from("payouts").insert({
      workshop_id: b.workshop_id,
      booking_id: b.id,
      gross_idr: gross,
      commission_idr: commission,
      net_idr: net,
      status: "scheduled",
      scheduled_for: today,
    });

    await supabase
      .from("bookings")
      .update({ status: "PAYOUT", updated_at: now.toISOString() })
      .eq("id", b.id);

    created++;
    // TODO: panggil disbursement API gateway untuk net_idr ke rekening bengkel.
  }

  return new Response(JSON.stringify({ ok: true, payouts_created: created }), {
    headers: { "content-type": "application/json" },
  });
});
