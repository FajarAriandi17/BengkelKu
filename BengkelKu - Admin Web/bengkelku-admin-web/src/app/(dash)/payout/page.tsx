import { createClient } from "@/lib/supabase/server";
import { StatusBadge } from "@/components/StatusBadge";

const rupiah = (n: number) =>
  new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    maximumFractionDigits: 0,
  }).format(n);

export default async function PayoutPage() {
  const supabase = createClient();
  const { data: payouts } = await supabase
    .from("payouts")
    .select("id, workshop_id, gross_idr, commission_idr, net_idr, status, scheduled_for")
    .order("scheduled_for", { ascending: false })
    .limit(200);

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-ink">Payout</h1>
      <div className="overflow-hidden rounded-lg bg-panel shadow-sm">
        <table className="w-full text-sm">
          <thead className="bg-panel2 text-left text-ink/60">
            <tr>
              <th className="px-4 py-3 font-semibold">Jadwal</th>
              <th className="px-4 py-3 font-semibold">Bruto</th>
              <th className="px-4 py-3 font-semibold">Komisi (8%)</th>
              <th className="px-4 py-3 font-semibold">Neto</th>
              <th className="px-4 py-3 font-semibold">Status</th>
            </tr>
          </thead>
          <tbody>
            {(payouts ?? []).map((p) => (
              <tr key={p.id} className="border-t border-blueSoft/50">
                <td className="px-4 py-3 text-ink/70">{p.scheduled_for}</td>
                <td className="px-4 py-3 text-ink">{rupiah(p.gross_idr)}</td>
                <td className="px-4 py-3 text-ink/70">{rupiah(p.commission_idr)}</td>
                <td className="px-4 py-3 font-medium text-ink">{rupiah(p.net_idr)}</td>
                <td className="px-4 py-3">
                  <StatusBadge status={p.status} />
                </td>
              </tr>
            ))}
            {(!payouts || payouts.length === 0) && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-ink/50">
                  belum ada payout.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
