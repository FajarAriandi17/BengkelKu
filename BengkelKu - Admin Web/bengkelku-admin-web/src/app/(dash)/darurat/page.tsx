import { createClient } from "@/lib/supabase/server";
import { requireAdmin, rupiah } from "@/lib/admin";
import { AutoRefresh } from "@/components/AutoRefresh";
import { DataTable, ErrorBox, MapBadge, PageTitle, StatCard } from "@/components/DataTable";
import { SOS_PROBLEM, SOS_STATUS } from "@/lib/labels";

type Live = {
  id: string; code: string; status: string; problem_code: string; tier: number; wave: number; total: number;
  created_at: string; updated_at: string; age_seconds: number; workshop_name: string | null;
  offers_sent: number; needs_attention: boolean;
};

const mmss = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

// Monitor darurat (SOS) aktif — diperbarui otomatis tiap 10 detik.
export default async function DaruratPage() {
  await requireAdmin("/darurat");
  const supabase = createClient();
  const [{ data, error }, { data: stats }] = await Promise.all([
    supabase.rpc("admin_sos_live"),
    supabase.rpc("admin_dashboard_stats"),
  ]);
  const rows = (data ?? []) as Live[];
  const s = (stats ?? {}) as Record<string, number>;
  const attention = rows.filter((r) => r.needs_attention).length;

  return (
    <div>
      <PageTitle title="Darurat (SOS) Live"
        subtitle="permintaan darurat yang sedang berjalan di aplikasi. baris merah = > 3 menit belum ada bengkel."
        right={<AutoRefresh seconds={10} />} />
      <ErrorBox message={error?.message} />
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard label="SOS aktif" value={rows.length} />
        <StatCard label="butuh perhatian" value={attention} tone={attention ? "bad" : "ok"} />
        <StatCard label="bengkel siaga online" value={s.standby_ready ?? 0} tone="ok" />
        <StatCard label="tiket bantuan terbuka" value={s.tickets_open ?? 0} href="/bantuan" tone="warn" />
      </div>
      <DataTable
        head={["Kode", "Masalah", "Status", "Usia", "Gelombang / Tawaran", "Bengkel", "Biaya"]}
        empty="tidak ada SOS aktif saat ini."
        rows={rows.map((r) => ({
          key: r.id,
          highlight: r.needs_attention,
          cells: [
            <span key="c" className="font-mono font-semibold text-ink">{r.code}</span>,
            SOS_PROBLEM[r.problem_code] ?? r.problem_code,
            <MapBadge key="s" map={SOS_STATUS} value={r.status} />,
            <span key="a" className={r.needs_attention ? "font-semibold text-bad" : ""}>{mmss(r.age_seconds)}</span>,
            `gel. ${r.wave} · ${r.offers_sent} tawaran · tier ${r.tier}`,
            r.workshop_name ?? <span key="w" className="text-ink/40">belum ada</span>,
            rupiah(r.total),
          ],
        }))}
      />
    </div>
  );
}
