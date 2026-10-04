import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

// POST /api/verify — keputusan verifikasi bengkel.
// Memanggil RPC admin_verify_workshop dengan SESI ADMIN sendiri: database
// memeriksa peran verifikator, mengubah status + dokumen + peran pemilik,
// menulis audit_logs, dan mengirim notifikasi ke aplikasi pemilik (atomik).
export async function POST(req: Request) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "sesi berakhir, silakan masuk lagi" }, { status: 401 });

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "format permintaan tidak valid" }, { status: 400 });
  }
  const { workshopId, decision, checklist, reasonCode, note } = body as {
    workshopId?: string;
    decision?: string;
    checklist?: Record<string, boolean>;
    reasonCode?: string | null;
    note?: string | null;
  };

  if (!workshopId || !decision || !["approve", "reject"].includes(decision)) {
    return NextResponse.json({ error: "data keputusan tidak lengkap" }, { status: 400 });
  }

  const { data, error } = await supabase.rpc("admin_verify_workshop", {
    p_workshop_id: workshopId,
    p_decision: decision,
    p_reason_code: decision === "reject" ? reasonCode ?? null : null,
    p_note: note?.trim() || null,
    p_checklist: checklist ?? {},
  });

  if (error) {
    const status = /Hanya admin|verifikator/i.test(error.message) ? 403 : 400;
    return NextResponse.json({ error: error.message }, { status });
  }
  return NextResponse.json({ ok: true, result: data });
}
