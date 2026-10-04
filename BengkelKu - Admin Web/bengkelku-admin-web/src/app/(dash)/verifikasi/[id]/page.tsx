import { notFound } from "next/navigation";
import { createClient, createAdminClient } from "@/lib/supabase/server";
import { DocViewer } from "@/components/DocViewer";
import { VerificationDecision } from "@/components/VerificationDecision";

// Detail verifikasi: profil bengkel + dokumen (signed URL) + checklist + keputusan.
export default async function VerifikasiDetail({
  params,
}: {
  params: { id: string };
}) {
  const supabase = createClient();
  const admin = createAdminClient(); // service role untuk signed URL dokumen privat

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: ws } = await supabase
    .from("workshops")
    .select("id, name, address, phone, description, status")
    .eq("id", params.id)
    .maybeSingle();

  if (!ws) notFound();

  const { data: docs } = await admin
    .from("workshop_documents")
    .select("id, type, storage_path")
    .eq("workshop_id", params.id);

  // Buat signed URL singkat (≤ 60 dtk) untuk tiap dokumen & catat akses.
  const docViews = await Promise.all(
    (docs ?? []).map(async (d) => {
      const { data } = await admin.storage
        .from("verification-docs")
        .createSignedUrl(d.storage_path, 60);
      return { id: d.id, type: d.type, url: data?.signedUrl ?? "" };
    }),
  );

  if (docViews.length > 0) {
    await admin.from("audit_logs").insert({
      actor_id: user?.id ?? null,
      action: "VIEW_DOCUMENTS",
      target_type: "workshop",
      target_id: params.id,
      meta: { count: docViews.length },
    });
  }

  const watermark = user?.email ?? "admin";

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <div className="lg:col-span-2">
        <h1 className="mb-1 text-2xl font-bold text-ink">{ws.name}</h1>
        <p className="mb-6 text-sm text-ink/60">{ws.address}</p>

        <div className="mb-6 rounded-lg bg-panel p-5 shadow-sm">
          <h2 className="mb-3 font-semibold text-ink">Profil</h2>
          <dl className="grid grid-cols-2 gap-3 text-sm">
            <dt className="text-ink/50">Telepon</dt>
            <dd className="text-ink">{ws.phone ?? "-"}</dd>
            <dt className="text-ink/50">Deskripsi</dt>
            <dd className="text-ink">{ws.description ?? "-"}</dd>
          </dl>
        </div>

        <h2 className="mb-3 font-semibold text-ink">Dokumen Verifikasi</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {docViews.map((d) => (
            <div key={d.id}>
              <div className="mb-1 text-xs font-semibold uppercase text-ink/50">
                {d.type === "ktp"
                  ? "KTP"
                  : d.type === "selfie"
                  ? "Selfie + KTP"
                  : "Foto Lokasi"}
              </div>
              <DocViewer signedUrl={d.url} watermark={watermark} />
            </div>
          ))}
          {docViews.length === 0 && (
            <p className="text-sm text-ink/50">belum ada dokumen diunggah.</p>
          )}
        </div>
      </div>

      <div className="lg:col-span-1">
        <VerificationDecision workshopId={ws.id} />
      </div>
    </div>
  );
}
