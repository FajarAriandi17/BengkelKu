import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ago, requireAdmin } from "@/lib/admin";
import { DataTable, ErrorBox, MapBadge, PageTitle } from "@/components/DataTable";
import { CHAT_REPORT_STATE } from "@/lib/labels";

// Laporan chat dari aplikasi (menu ⋮ → laporkan percakapan).
export default async function ModerasiPage({ searchParams }: { searchParams: { all?: string } }) {
  await requireAdmin("/moderasi");
  const supabase = createClient();
  let q = supabase
    .from("chat_reports")
    .select("id, thread_id, reason, state, created_at, reporter:users!chat_reports_reporter_id_fkey(full_name)")
    .order("created_at", { ascending: true })
    .limit(200);
  if (!searchParams.all) q = q.in("state", ["open", "reviewing"]);
  const { data, error } = await q;
  type Row = { id: string; thread_id: string; reason: string; state: string; created_at: string; reporter: { full_name: string | null } | null };
  const rows = (data ?? []) as unknown as Row[];

  return (
    <div>
      <PageTitle
        title="Moderasi Chat"
        subtitle="membuka percakapan terlapor tercatat di audit log."
        right={
          <Link href={searchParams.all ? "/moderasi" : "/moderasi?all=1"} className="text-sm font-semibold text-blue">
            {searchParams.all ? "hanya yang terbuka" : "tampilkan semua"}
          </Link>
        }
      />
      <ErrorBox message={error?.message} />
      <DataTable
        head={["Pelapor", "Alasan", "Status", "Dilaporkan", ""]}
        empty="tidak ada laporan chat."
        rows={rows.map((r) => ({
          key: r.id,
          cells: [
            r.reporter?.full_name ?? "-",
            <span key="r" className="line-clamp-2 max-w-sm">{r.reason}</span>,
            <MapBadge key="s" map={CHAT_REPORT_STATE} value={r.state} />,
            ago(r.created_at),
            <Link key="l" href={`/moderasi/${r.id}`} className="rounded-md bg-blue px-3 py-1.5 text-xs font-semibold text-white">tinjau</Link>,
          ],
        }))}
      />
    </div>
  );
}
