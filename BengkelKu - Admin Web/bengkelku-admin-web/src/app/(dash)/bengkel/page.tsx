import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { canAccess, dateTime, requireAdmin } from "@/lib/admin";
import { DataTable, ErrorBox, PageTitle } from "@/components/DataTable";
import { StatusBadge } from "@/components/StatusBadge";
import { RpcAction } from "@/components/RpcAction";

const STATUSES = ["", "verified", "pending", "suspended", "rejected", "draft"];

// Semua bengkel + filter status/pencarian + suspensi/aktifkan kembali (RPC + audit).
export default async function BengkelPage({ searchParams }: { searchParams: { q?: string; status?: string } }) {
  const me = await requireAdmin("/bengkel");
  const supabase = createClient();
  const q = (searchParams.q ?? "").trim();
  const status = STATUSES.includes(searchParams.status ?? "") ? searchParams.status ?? "" : "";

  let query = supabase
    .from("workshops")
    .select("id, name, address, phone, status, rating_avg, rating_count, verified_at, created_at, owner:users!workshops_owner_id_fkey(full_name)")
    .order("created_at", { ascending: false })
    .limit(200);
  if (status) query = query.eq("status", status);
  if (q) query = query.or(`name.ilike.%${q.replace(/[%,()]/g, "")}%,address.ilike.%${q.replace(/[%,()]/g, "")}%`);
  const { data, error } = await query;

  type Row = {
    id: string; name: string; address: string | null; phone: string | null; status: string;
    rating_avg: number; rating_count: number; verified_at: string | null; created_at: string;
    owner: { full_name: string | null } | null;
  };
  const rows = (data ?? []) as unknown as Row[];
  const canModerate = canAccess(me.role, "/bengkel");

  return (
    <div>
      <PageTitle title="Bengkel" subtitle="bengkel mitra di aplikasi. suspensi langsung menyembunyikan bengkel dari pencarian & SOS." />
      <form className="mb-4 flex flex-wrap gap-2" method="get">
        <input
          name="q"
          defaultValue={q}
          placeholder="cari nama / alamat"
          aria-label="cari bengkel"
          className="w-64 rounded-md border border-blueSoft bg-panel px-3 py-2 text-sm"
        />
        <select name="status" defaultValue={status} aria-label="filter status" className="rounded-md border border-blueSoft bg-panel px-3 py-2 text-sm">
          <option value="">semua status</option>
          <option value="verified">terverifikasi</option>
          <option value="pending">menunggu</option>
          <option value="suspended">disuspensi</option>
          <option value="rejected">ditolak</option>
          <option value="draft">draf</option>
        </select>
        <button className="rounded-md bg-blue px-4 py-2 text-sm font-semibold text-white">terapkan</button>
      </form>
      <ErrorBox message={error?.message} />
      <DataTable
        head={["Bengkel", "Pemilik", "Status", "Rating", "Terdaftar", "Aksi"]}
        empty="tidak ada bengkel yang cocok."
        rows={rows.map((w) => ({
          key: w.id,
          cells: [
            <div key="n">
              <div className="font-medium text-ink">{w.name}</div>
              <div className="text-xs text-ink/50">{w.address ?? "-"}</div>
            </div>,
            w.owner?.full_name ?? "-",
            <StatusBadge key="s" status={w.status} />,
            w.rating_count > 0 ? `★ ${Number(w.rating_avg).toFixed(1)} (${w.rating_count})` : "-",
            dateTime(w.created_at),
            <div key="a" className="min-w-[180px]">
              {w.status === "pending" && (
                <Link href={`/verifikasi/${w.id}`} className="text-xs font-semibold text-blue">tinjau verifikasi →</Link>
              )}
              {canModerate && w.status === "verified" && (
                <RpcAction
                  rpc="admin_set_workshop_status"
                  args={{ p_workshop_id: w.id, p_status: "suspended" }}
                  fields={[{ name: "p_reason", label: "alasan suspensi", type: "textarea", required: true, minLength: 5 }]}
                  label="suspensi"
                  tone="danger"
                  confirmText={`Suspensi ${w.name}? Bengkel tidak akan tampil di aplikasi.`}
                  successText="bengkel disuspensi"
                />
              )}
              {canModerate && w.status === "suspended" && (
                <RpcAction
                  rpc="admin_set_workshop_status"
                  args={{ p_workshop_id: w.id, p_status: "verified" }}
                  fields={[{ name: "p_reason", label: "catatan pengaktifan", type: "textarea", required: true, minLength: 5 }]}
                  label="aktifkan kembali"
                  tone="ok"
                  successText="bengkel aktif kembali"
                />
              )}
            </div>,
          ],
        }))}
      />
    </div>
  );
}
