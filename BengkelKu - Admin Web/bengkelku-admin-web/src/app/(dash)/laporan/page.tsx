import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireAdmin, rupiah } from "@/lib/admin";
import { DataTable, ErrorBox, PageTitle, StatCard } from "@/components/DataTable";
import { BOOKING_STATUS } from "@/lib/labels";

type Report = {
  days: number; bookings_total: number; bookings_done: number; gmv_idr: number; commission_idr: number;
  bookings_by_status: Record<string, number>; sos_total: number; sos_done: number; sos_no_workshop: number;
  sos_revenue_idr: number; new_users: number; new_workshops: number;
  top_workshops: { name: string; bookings: number; gmv: number }[];
};

// Laporan bisnis ringkas (7/30/90 hari).
export default async function LaporanPage({ searchParams }: { searchParams: { days?: string } }) {
  await requireAdmin("/laporan");
  const days = [7, 30, 90].includes(Number(searchParams.days)) ? Number(searchParams.days) : 30;
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_report_summary", { p_days: days });
  const r = data as Report | null;
  const pct = (a: number, b: number) => (b > 0 ? `${Math.round((a / b) * 100)}%` : "-");

  return (
    <div>
      <PageTitle
        title="Laporan"
        subtitle={`ringkasan ${days} hari terakhir`}
        right={
          <div className="flex gap-2">
            {[7, 30, 90].map((d) => (
              <Link key={d} href={`/laporan?days=${d}`} className={`rounded-pill px-3 py-1.5 text-xs font-semibold ${d === days ? "bg-blue text-white" : "bg-panel text-ink/70"}`}>{d} hari</Link>
            ))}
          </div>
        }
      />
      <ErrorBox message={error?.message} />
      {r && (
        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
            <StatCard label="GMV booking selesai" value={rupiah(r.gmv_idr)} tone="ok" />
            <StatCard label="pendapatan komisi" value={rupiah(r.commission_idr)} />
            <StatCard label="pendapatan SOS" value={rupiah(r.sos_revenue_idr)} />
            <StatCard label="booking selesai" value={`${r.bookings_done} / ${r.bookings_total}`} />
            <StatCard label="SOS tertangani" value={`${r.sos_done} / ${r.sos_total} (${pct(r.sos_done, r.sos_total)})`} />
            <StatCard label="SOS tanpa bengkel" value={r.sos_no_workshop} tone={r.sos_no_workshop ? "bad" : "ok"} />
            <StatCard label="pengguna baru" value={r.new_users} />
            <StatCard label="bengkel baru" value={r.new_workshops} />
          </div>
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <section>
              <h2 className="mb-3 font-semibold text-ink">Booking per status</h2>
              <DataTable
                head={["Status", "Jumlah"]}
                rows={Object.entries(r.bookings_by_status).map(([k, v]) => ({ key: k, cells: [BOOKING_STATUS[k]?.label ?? k, v] }))}
              />
            </section>
            <section>
              <h2 className="mb-3 font-semibold text-ink">Bengkel teratas (GMV)</h2>
              <DataTable
                head={["Bengkel", "Booking", "GMV"]}
                rows={r.top_workshops.map((w) => ({ key: w.name, cells: [w.name, w.bookings, rupiah(w.gmv)] }))}
              />
            </section>
          </div>
        </div>
      )}
    </div>
  );
}
