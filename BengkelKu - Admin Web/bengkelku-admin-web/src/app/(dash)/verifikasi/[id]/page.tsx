import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient, createAdminClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { DocViewer } from "@/components/DocViewer";
import { VerificationDecision } from "@/components/VerificationDecision";
import { StatusBadge } from "@/components/StatusBadge";
import { Badge } from "@/components/DataTable";

const DOC_LABEL: Record<string, string> = { ktp: "KTP", selfie: "Selfie + KTP", location: "Foto Lokasi" };

function distanceM(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Detail verifikasi: profil + pemilik + pin + dokumen (signed URL ≤ 60 dtk) + keputusan.
export default async function VerifikasiDetail({ params }: { params: { id: string } }) {
  const me = await requireAdmin("/verifikasi");
  const supabase = createClient();

  const { data: ws } = await supabase
    .from("workshops")
    .select("id, name, address, phone, description, status, rejected_reason, submitted_at, submission_count, created_at, owner:users!workshops_owner_id_fkey(id, full_name, phone)")
    .eq("id", params.id)
    .maybeSingle();
  if (!ws) notFound();
  const w = ws as unknown as {
    id: string; name: string; address: string | null; phone: string | null; description: string | null;
    status: string; rejected_reason: string | null; submitted_at: string | null; submission_count: number; created_at: string;
    owner: { id: string; full_name: string | null; phone: string | null } | null;
  };

  const { data: geo } = await supabase.rpc("admin_workshop_geo", { p_workshop_id: params.id });
  const pin = geo as { lat: number; lng: number } | null;

  // Dokumen dibaca dengan sesi admin (RLS verifikator); hanya signed URL yang memakai service role.
  const { data: docs } = await supabase
    .from("workshop_documents")
    .select("id, type, storage_path, gps_lat, gps_lng, status, created_at")
    .eq("workshop_id", params.id)
    .order("created_at", { ascending: false });

  // Ambil dokumen TERBARU per jenis (pengajuan ulang menimpa yang lama).
  const latest = new Map<string, NonNullable<typeof docs>[number]>();
  for (const d of docs ?? []) if (!latest.has(d.type)) latest.set(d.type, d);

  const admin = createAdminClient();
  const docViews = await Promise.all(
    ["ktp", "selfie", "location"].map(async (type) => {
      const d = latest.get(type);
      if (!d) return { type, url: "", gap: null as number | null };
      const { data } = await admin.storage.from("verification-docs").createSignedUrl(d.storage_path, 60);
      const gap = pin && d.gps_lat != null && d.gps_lng != null ? distanceM(pin, { lat: d.gps_lat, lng: d.gps_lng }) : null;
      return { type, url: data?.signedUrl ?? "", gap };
    }),
  );

  if (latest.size > 0) {
    await supabase.from("audit_logs").insert({
      actor_id: me.id,
      action: "VIEW_DOCUMENTS",
      target_type: "workshop",
      target_id: params.id,
      meta: { count: latest.size },
    });
  }

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <div className="lg:col-span-2">
        <Link href="/verifikasi" className="text-sm text-blue">← kembali ke antrean</Link>
        <div className="mb-1 mt-2 flex flex-wrap items-center gap-2">
          <h1 className="text-2xl font-bold text-ink">{w.name}</h1>
          <StatusBadge status={w.status} />
          {w.submission_count > 1 && <Badge label={`pengajuan ke-${w.submission_count}`} cls="bg-warnSoft text-warn" />}
        </div>
        <p className="mb-6 text-sm text-ink/60">{w.address}</p>

        <div className="mb-6 rounded-lg bg-panel p-5 shadow-sm">
          <h2 className="mb-3 font-semibold text-ink">Profil & Pemilik</h2>
          <dl className="grid grid-cols-[140px_1fr] gap-x-4 gap-y-2 text-sm">
            <dt className="text-ink/50">Pemilik</dt>
            <dd className="text-ink">{w.owner?.full_name ?? "-"} {w.owner?.phone ? `· ${w.owner.phone}` : ""}</dd>
            <dt className="text-ink/50">Telepon bengkel</dt>
            <dd className="text-ink">{w.phone ?? "-"}</dd>
            <dt className="text-ink/50">Deskripsi</dt>
            <dd className="text-ink">{w.description ?? "-"}</dd>
            <dt className="text-ink/50">Diajukan</dt>
            <dd className="text-ink">{dateTime(w.submitted_at ?? w.created_at)}</dd>
            <dt className="text-ink/50">Pin lokasi</dt>
            <dd className="text-ink">
              {pin ? (
                <a
                  className="text-blue underline"
                  target="_blank"
                  rel="noreferrer"
                  href={`https://www.google.com/maps?q=${pin.lat},${pin.lng}`}
                >
                  {pin.lat.toFixed(5)}, {pin.lng.toFixed(5)} (buka peta)
                </a>
              ) : (
                <span className="text-bad">belum ada pin</span>
              )}
            </dd>
            {w.rejected_reason && (
              <>
                <dt className="text-ink/50">Penolakan terakhir</dt>
                <dd className="text-bad">{w.rejected_reason}</dd>
              </>
            )}
          </dl>
        </div>

        <h2 className="mb-3 font-semibold text-ink">Dokumen Verifikasi</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {docViews.map((d) => (
            <div key={d.type}>
              <div className="mb-1 text-xs font-semibold uppercase text-ink/50">{DOC_LABEL[d.type]}</div>
              {d.url ? (
                <DocViewer signedUrl={d.url} watermark={me.email} />
              ) : (
                <div className="flex h-40 items-center justify-center rounded-md border border-dashed border-bad/40 text-xs text-bad">
                  belum diunggah
                </div>
              )}
              {d.gap != null && (
                <p className={`mt-1 text-xs ${d.gap > 300 ? "font-semibold text-bad" : "text-ok"}`}>
                  {d.gap > 300 ? "⚠ " : "✓ "}GPS foto {Math.round(d.gap)} m dari pin
                </p>
              )}
            </div>
          ))}
        </div>
      </div>

      <div className="lg:col-span-1">
        {w.status === "pending" ? (
          <VerificationDecision workshopId={w.id} />
        ) : (
          <div className="rounded-lg bg-panel p-5 text-sm text-ink/60 shadow-sm">
            bengkel ini tidak sedang menunggu verifikasi (status: <StatusBadge status={w.status} />).
          </div>
        )}
      </div>
    </div>
  );
}
