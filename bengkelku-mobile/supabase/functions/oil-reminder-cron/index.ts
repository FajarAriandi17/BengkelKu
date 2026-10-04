// oil-reminder-cron — Supabase Edge Function (Deno)
//
// Dijalankan harian (cron). Menghitung ulang status pengingat oli setiap kendaraan
// berdasarkan sisa km & sisa hari, lalu membuat notifikasi untuk 'soon'/'late'.
//
// Logika stage HARUS sama dengan lib/features/oil/domain/oil_calculator.dart:
//   late : sisa km <= 0 ATAU sisa hari <= 0
//   soon : sisa km <= 300 ATAU sisa hari <= 7
//   ok   : selain itu
//
// Jadwalkan via pg_cron / Supabase schedule memanggil endpoint ini.
// Secret: SUPABASE_URL, SERVICE_ROLE_KEY

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!,
);

const SOON_KM = 300;
const SOON_DAYS = 7;

type Stage = "ok" | "soon" | "late";

function oilStage(remainingKm: number, remainingDays: number): Stage {
  if (remainingKm <= 0 || remainingDays <= 0) return "late";
  if (remainingKm <= SOON_KM || remainingDays <= SOON_DAYS) return "soon";
  return "ok";
}

Deno.serve(async () => {
  const now = new Date();

  // Ambil reminder + odometer kendaraan.
  const { data: rows, error } = await supabase
    .from("oil_reminders")
    .select("id, vehicle_id, target_km, target_date, stage, snoozed_until, vehicles(odometer, user_id)");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let notified = 0;

  for (const r of rows ?? []) {
    // Lewati bila masih di-snooze.
    if (r.snoozed_until && new Date(r.snoozed_until) > now) continue;

    const vehicle = (r as any).vehicles;
    if (!vehicle) continue;

    const remainingKm = r.target_km - vehicle.odometer;
    const remainingDays = Math.ceil(
      (new Date(r.target_date).getTime() - now.getTime()) / 86400000,
    );
    const stage = oilStage(remainingKm, remainingDays);

    if (stage !== r.stage) {
      await supabase
        .from("oil_reminders")
        .update({ stage, updated_at: now.toISOString() })
        .eq("id", r.id);
    }

    if (stage === "soon" || stage === "late") {
      await supabase.from("notifications").insert({
        user_id: vehicle.user_id,
        kind: "oil",
        title: stage === "late"
          ? "oli motor kamu sudah telat ganti"
          : "oli motor kamu sudah dekat waktunya ganti",
        body: "yuk booking servis sekarang biar mesin tetap awet.",
        data: { vehicle_id: r.vehicle_id, stage },
      });
      notified++;
      // TODO: kirim push via FCM/APNs memakai token tersimpan.
    }
  }

  return new Response(JSON.stringify({ ok: true, notified }), {
    headers: { "content-type": "application/json" },
  });
});
