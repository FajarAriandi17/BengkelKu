// admin-verify-decision — Supabase Edge Function (Deno)
//
// Alternatif serverless untuk keputusan verifikasi (approve/reject) bila tidak
// memakai Route Handler Next.js. Memperbarui status workshop + audit + notifikasi.
// Secret: SUPABASE_URL, SERVICE_ROLE_KEY

import { createClient } from "jsr:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  const { data: userData } = await admin.auth.getUser(token);
  const user = userData.user;
  if (!user) return new Response("Unauthorized", { status: 401 });

  const { data: adminRow } = await admin
    .from("admin_users")
    .select("id, is_active, role")
    .eq("id", user.id)
    .maybeSingle();
  if (!adminRow?.is_active) return new Response("Forbidden", { status: 403 });

  const { workshop_id, decision, checklist, reason_code, note } = await req.json();
  if (!workshop_id || !["approve", "reject"].includes(decision)) {
    return new Response("Bad Request", { status: 400 });
  }

  const status = decision === "approve" ? "verified" : "rejected";
  await admin
    .from("workshops")
    .update({
      status,
      rejected_reason: decision === "reject" ? (note ?? reason_code) : null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", workshop_id);

  await admin.from("audit_logs").insert({
    actor_id: user.id,
    action: decision === "approve" ? "APPROVE_WORKSHOP" : "REJECT_WORKSHOP",
    target_type: "workshop",
    target_id: workshop_id,
    meta: { checklist, reason_code, note },
  });

  const { data: ws } = await admin
    .from("workshops")
    .select("owner_id")
    .eq("id", workshop_id)
    .maybeSingle();

  if (ws?.owner_id) {
    await admin.from("notifications").insert({
      user_id: ws.owner_id,
      kind: "verification",
      title:
        decision === "approve"
          ? "selamat! bengkel kamu sudah tayang di BengkelKu"
          : "pendaftaran bengkel kamu belum disetujui",
      body:
        decision === "approve"
          ? "pelanggan kini bisa menemukan dan memesan servis di bengkelmu."
          : (note ?? "silakan perbaiki data lalu ajukan ulang."),
      data: { workshop_id },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" },
  });
});
