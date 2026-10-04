import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin, rupiah } from "@/lib/admin";
import { DataTable, ErrorBox, MapBadge, PageTitle } from "@/components/DataTable";
import { BOOKING_STATUS } from "@/lib/labels";

// Transaksi booking servis (read-only; pembayaran via payment gateway).
export default async function TransaksiPage({ searchParams }: { searchParams: { status?: string } }) {
  await requireAdmin("/transaksi");
  const supabase = createClient();
  const status = searchParams.status && BOOKING_STATUS[searchParams.status] ? searchParams.status : "";
  let q = supabase
    .from("bookings")
    .select("id, status, scheduled_at, total_idr, commission_rate, cancel_reason, created_at, workshop:workshops(name), rider:users!bookings_rider_id_fkey(full_name)")
    .order("created_at", { ascending: false })
    .limit(200);
  if (status) q = q.eq("status", status);
  const { data, error } = await q;
  type Row = {
    id: string; status: string; scheduled_at: string; total_idr: number; commission_rate: number;
    cancel_reason: string | null; created_at: string;
    workshop: { name: string } | null; rider: { full_name: string | null } | null;
  };
  const rows = (data ?? []) as unknown as Row[];
  const total = rows.filter((r) => ["SELESAI", "PAYOUT"].includes(r.status)).reduce((a, r) => a + r.total_idr, 0);

  return (
    <div>
      <PageTitle title="Transaksi" subtitle={`200 booking terbaru · GMV selesai di daftar ini: ${rupiah(total)}`} />
      <div className="mb-4 flex flex-wrap gap-2">
        <Link href="/transaksi" className={`rounded-pill px-3 py-1.5 text-xs font-semibold ${!status ? "bg-blue text-white" : "bg-panel text-ink/70"}`}>semua</Link>
        {Object.entries(BOOKING_STATUS).map(([k, v]) => (
          <Link key={k} href={`/transaksi?status=${k}`} className={`rounded-pill px-3 py-1.5 text-xs font-semibold ${status === k ? "bg-blue text-white" : "bg-panel text-ink/70"}`}>{v.label}</Link>
        ))}
      </div>
      <ErrorBox message={error?.message} />
      <DataTable
        head={["ID", "Pengendara", "Bengkel", "Jadwal", "Total", "Komisi", "Status"]}
        empty="belum ada transaksi."
        rows={rows.map((b) => ({
          key: b.id,
          cells: [
            <span key="i" className="font-mono text-xs">{b.id.slice(0, 8)}</span>,
            b.rider?.full_name ?? "-",
            b.workshop?.name ?? "-",
            dateTime(b.scheduled_at),
            rupiah(b.total_idr),
            rupiah(Math.round(b.total_idr * Number(b.commission_rate))),
            <div key="s"><MapBadge map={BOOKING_STATUS} value={b.status} />{b.cancel_reason && <div className="mt-1 text-xs text-ink/50">{b.cancel_reason}</div>}</div>,
          ],
        }))}
      />
    </div>
  );
}
