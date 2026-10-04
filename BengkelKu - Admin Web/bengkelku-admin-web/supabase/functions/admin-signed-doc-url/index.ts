// admin-signed-doc-url — Supabase Edge Function (Deno)
//
// Membuat signed URL singkat (<= 60 dtk) untuk dokumen verifikasi privat,
// HANYA untuk admin aktif, dan menulis audit log akses.
//
// Alternatif server: Route Handler Next.js (lihat src/app/(dash)/verifikasi/[id]/page.tsx).
// Secret: SUPABASE_URL, SERVICE_ROLE_KEY

import { createClient } from "jsr:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  // Verifikasi caller lewat Authorization Bearer (JWT admin).
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  const { data: userData } = await admin.auth.getUser(token);
  const user = userData.user;
  if (!user) return new Response("Unauthorized", { status: 401 });

  const { data: adminRow } = await admin
    .from("admin_users")
    .select("id, is_active")
    .eq("id", user.id)
    .maybeSingle();
  if (!adminRow?.is_active) return new Response("Forbidden", { status: 403 });

  const { document_id } = await req.json();
  const { data: doc } = await admin
    .from("workshop_documents")
    .select("id, workshop_id, storage_path")
    .eq("id", document_id)
    .maybeSingle();
  if (!doc) return new Response("Not Found", { status: 404 });

  const { data: signed } = await admin.storage
    .from("verification-docs")
    .createSignedUrl(doc.storage_path, 60);

  await admin.from("audit_logs").insert({
    actor_id: user.id,
    action: "VIEW_DOCUMENTS",
    target_type: "workshop",
    target_id: doc.workshop_id,
    meta: { document_id },
  });

  return new Response(JSON.stringify({ url: signed?.signedUrl ?? null }), {
    headers: { "content-type": "application/json" },
  });
});
