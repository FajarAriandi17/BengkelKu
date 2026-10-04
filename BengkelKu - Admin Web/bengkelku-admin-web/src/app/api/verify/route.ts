import { NextResponse } from "next/server";
import { createClient, createAdminClient } from "@/lib/supabase/server";

// POST /api/verify — simpan keputusan verifikasi bengkel + tulis audit log.
// Hanya admin terautentikasi. Memakai service role untuk update lintas-RLS.
export async function POST(req: Request) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = await req.json();
  const { workshopId, decision, checklist, reasonCode, note } = body ?? {};

  if (!workshopId || !["approve", "reject"].includes(decision)) {
    return NextResponse.json({ error: "bad request" }, { status: 400 });
  }

  const admin = createAdminClient();

  // Pastikan pemanggil benar-benar admin (ada di admin_users).
  const { data: adminRow } = await admin
    .from("admin_users")
    .select("id, role, is_active")
    .eq("id", user.id)
    .maybeSingle();

  if (!adminRow || !adminRow.is_active) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  const newStatus = decision === "approve" ? "verified" : "rejected";

  const { error: updErr } = await admin
    .from("workshops")
    .update({
      status: newStatus,
      rejected_reason: decision === "reject" ? (note ?? reasonCode) : null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", workshopId);

  if (updErr) {
    return NextResponse.json({ error: updErr.message }, { status: 500 });
  }

  await admin.from("audit_logs").insert({
    actor_id: user.id,
    action: decision === "approve" ? "APPROVE_WORKSHOP" : "REJECT_WORKSHOP",
    target_type: "workshop",
    target_id: workshopId,
    meta: { checklist, reasonCode, note },
  });

  // Notifikasi ke pemilik bengkel.
  const { data: ws } = await admin
    .from("workshops")
    .select("owner_id, name")
    .eq("id", workshopId)
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
      data: { workshop_id: workshopId },
    });
  }

  return NextResponse.json({ ok: true });
}
