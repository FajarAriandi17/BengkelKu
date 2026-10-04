import { createClient } from "@/lib/supabase/server";
import { requireAdmin, rupiah } from "@/lib/admin";
import { DataTable, ErrorBox, PageTitle, StatCard } from "@/components/DataTable";
import { StatusBadge } from "@/components/StatusBadge";
import { RpcAction } from "@/components/RpcAction";

// Payout ke bengkel: finance memproses → dibayar / gagal (notifikasi ke pemilik + audit).
export default async function PayoutPage() {
  await requireAdmin("/payout");
  const supabase = createClient();
  const { data, error } = await supabase
    .from("payouts")
    .select("id, workshop_id, gross_idr, commission_idr, net_idr, status, bank_account, scheduled_for, paid_at, workshop:workshops(name)")
    .order("scheduled_for", { ascending: false })
    .limit(200);
  type Row = {
    id: string; gross_idr: number; commission_idr: number; net_idr: number; status: string;
    bank_account: string | null; scheduled_for: string; paid_at: string | null; workshop: { name: string } | null;
  };
  const rows = (data ?? []) as unknown as Row[];
  const sum = (s: string) => rows.filter((r) => r.status === s).reduce((a, r) => a + r.net_idr, 0);

  return (
    <div>
      <PageTitle title="Payout" subtitle="pencairan dana servis ke rekening bengkel (komisi platform sudah dipotong)." />
      <ErrorBox message={error?.message} />
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
        <StatCard label="terjadwal" value={rupiah(sum("scheduled"))} />
        <StatCard label="diproses" value={rupiah(sum("processing"))} tone="warn" />
        <StatCard label="dibayar" value={rupiah(sum("paid"))} tone="ok" />
        <StatCard label="gagal" value={rupiah(sum("failed"))} tone="bad" />
      </div>
      <DataTable
        head={["Jadwal", "Bengkel", "Bruto", "Komisi", "Neto", "Rekening", "Status", "Aksi"]}
        empty="belum ada payout."
        rows={rows.map((p) => ({
          key: p.id,
          cells: [
            p.scheduled_for,
            p.workshop?.name ?? "-",
            rupiah(p.gross_idr),
            rupiah(p.commission_idr),
            <span key="n" className="font-semibold text-ink">{rupiah(p.net_idr)}</span>,
            p.bank_account ?? <span key="b" className="text-bad">belum ada</span>,
            <StatusBadge key="s" status={p.status} />,
            <div key="a" className="flex min-w-[160px] flex-col gap-2">
              {p.status === "scheduled" && (
                <RpcAction rpc="admin_payout_set_status" args={{ p_payout_id: p.id, p_status: "processing" }} label="proses" successText="diproses" />
              )}
              {(p.status === "processing" || p.status === "failed") && (
                <RpcAction rpc="admin_payout_set_status" args={{ p_payout_id: p.id, p_status: "paid" }} label="tandai dibayar" tone="ok"
                  confirmText={`Konfirmasi transfer ${rupiah(p.net_idr)} sudah dilakukan?`} successText="dibayar" />
              )}
              {(p.status === "scheduled" || p.status === "processing") && (
                <RpcAction rpc="admin_payout_set_status" args={{ p_payout_id: p.id, p_status: "failed" }} label="gagal" tone="danger"
                  fields={[{ name: "p_note", label: "alasan (dikirim ke pemilik)", type: "textarea", required: true, minLength: 5 }]} successText="ditandai gagal" />
              )}
            </div>,
          ],
        }))}
      />
    </div>
  );
}
