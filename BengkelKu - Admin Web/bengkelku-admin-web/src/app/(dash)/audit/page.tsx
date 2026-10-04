import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { DataTable, ErrorBox, PageTitle } from "@/components/DataTable";

// Audit log: jejak semua aksi admin (verifikasi, akses dokumen, tiket, config, tim, payout).
export default async function AuditPage({ searchParams }: { searchParams: { action?: string } }) {
  await requireAdmin("/audit");
  const supabase = createClient();
  let q = supabase
    .from("audit_logs")
    .select("id, actor_id, action, target_type, target_id, meta, created_at, actor:admin_users(email)")
    .order("created_at", { ascending: false })
    .limit(300);
  const action = (searchParams.action ?? "").trim().toUpperCase();
  if (action) q = q.ilike("action", `%${action.replace(/[%,]/g, "")}%`);
  const { data, error } = await q;
  type Row = {
    id: string; actor_id: string | null; action: string; target_type: string | null; target_id: string | null;
    meta: unknown; created_at: string; actor: { email: string } | null;
  };
  const rows = (data ?? []) as unknown as Row[];

  return (
    <div>
      <PageTitle title="Audit Log" subtitle="300 aksi terbaru. tidak dapat diubah atau dihapus dari panel." />
      <form method="get" className="mb-4 flex gap-2">
        <input name="action" defaultValue={action} placeholder="filter aksi, mis. VERIFY / TICKET" aria-label="filter aksi"
          className="w-72 rounded-md border border-blueSoft bg-panel px-3 py-2 text-sm" />
        <button className="rounded-md bg-blue px-4 py-2 text-sm font-semibold text-white">filter</button>
        {action && <Link href="/audit" className="px-2 py-2 text-sm text-blue">reset</Link>}
      </form>
      <ErrorBox message={error?.message} />
      <DataTable
        head={["Waktu", "Aktor", "Aksi", "Target", "Detail"]}
        empty="belum ada aktivitas."
        rows={rows.map((l) => ({
          key: l.id,
          cells: [
            <span key="t" className="whitespace-nowrap">{dateTime(l.created_at)}</span>,
            l.actor?.email ?? (l.actor_id ? l.actor_id.slice(0, 8) : "sistem"),
            <span key="a" className="font-mono text-xs font-semibold text-ink">{l.action}</span>,
            <span key="g" className="font-mono text-xs">{l.target_type ?? "-"}{l.target_id ? `:${l.target_id.slice(0, 8)}` : ""}</span>,
            <code key="m" className="line-clamp-2 max-w-md break-all text-[11px] text-ink/60">{l.meta ? JSON.stringify(l.meta) : ""}</code>,
          ],
        }))}
      />
    </div>
  );
}
