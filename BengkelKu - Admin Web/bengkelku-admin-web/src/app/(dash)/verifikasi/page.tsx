import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ago, dateTime, requireAdmin } from "@/lib/admin";
import { DataTable, ErrorBox, PageTitle, Badge } from "@/components/DataTable";

// Antrean verifikasi: bengkel 'pending' yang diajukan dari aplikasi (FIFO).
export default async function VerifikasiPage() {
  await requireAdmin("/verifikasi");
  const supabase = createClient();
  const { data: workshops, error } = await supabase
    .from("workshops")
    .select("id, name, address, phone, submitted_at, created_at, submission_count, owner:users!workshops_owner_id_fkey(full_name, phone)")
    .eq("status", "pending")
    .order("submitted_at", { ascending: true, nullsFirst: false })
    .limit(200);

  type Row = {
    id: string; name: string; address: string | null; phone: string | null;
    submitted_at: string | null; created_at: string; submission_count: number;
    owner: { full_name: string | null; phone: string | null } | null;
  };
  const rows = (workshops ?? []) as unknown as Row[];

  return (
    <div>
      <PageTitle
        title="Verifikasi Bengkel"
        subtitle="pengajuan dari aplikasi BengkelKu (pemilik bengkel). keputusan langsung terkirim sebagai notifikasi ke aplikasi."
      />
      <ErrorBox message={error?.message} />
      <DataTable
        head={["Nama Bengkel", "Pemilik", "Alamat", "Diajukan", ""]}
        empty="tidak ada antrean verifikasi saat ini. 🎉"
        rows={rows.map((w) => ({
          key: w.id,
          cells: [
            <div key="n">
              <div className="font-medium text-ink">{w.name}</div>
              {w.submission_count > 1 && <Badge label={`pengajuan ulang ke-${w.submission_count}`} cls="bg-warnSoft text-warn" />}
            </div>,
            <div key="o">
              <div>{w.owner?.full_name ?? "-"}</div>
              <div className="text-xs text-ink/50">{w.phone ?? w.owner?.phone ?? ""}</div>
            </div>,
            <span key="a" className="text-ink/70">{w.address ?? "-"}</span>,
            <div key="d">
              <div>{dateTime(w.submitted_at ?? w.created_at)}</div>
              <div className="text-xs text-ink/50">{ago(w.submitted_at ?? w.created_at)}</div>
            </div>,
            <Link key="l" href={`/verifikasi/${w.id}`} className="rounded-md bg-blue px-3 py-1.5 text-xs font-semibold text-white">
              tinjau
            </Link>,
          ],
        }))}
      />
    </div>
  );
}
