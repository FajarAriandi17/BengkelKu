import { createClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { Badge, DataTable, ErrorBox, PageTitle } from "@/components/DataTable";

type U = {
  id: string; full_name: string | null; email: string | null; phone: string | null; roles: string[];
  created_at: string; bookings: number; sos: number; workshops: number;
};

// Pengguna aplikasi (pengendara & pemilik bengkel).
export default async function PenggunaPage({ searchParams }: { searchParams: { q?: string } }) {
  await requireAdmin("/pengguna");
  const supabase = createClient();
  const q = (searchParams.q ?? "").trim();
  const { data, error } = await supabase.rpc("admin_list_users", { p_search: q || null, p_limit: 200 });
  const rows = (data ?? []) as U[];

  return (
    <div>
      <PageTitle title="Pengguna" subtitle={`${rows.length} pengguna ditampilkan (maks. 200 terbaru).`} />
      <form method="get" className="mb-4 flex gap-2">
        <input name="q" defaultValue={q} placeholder="cari nama / email / telepon" aria-label="cari pengguna"
          className="w-72 rounded-md border border-blueSoft bg-panel px-3 py-2 text-sm" />
        <button className="rounded-md bg-blue px-4 py-2 text-sm font-semibold text-white">cari</button>
      </form>
      <ErrorBox message={error?.message} />
      <DataTable
        head={["Nama", "Kontak", "Peran", "Booking", "SOS", "Bengkel", "Bergabung"]}
        empty="tidak ada pengguna yang cocok."
        rows={rows.map((u) => ({
          key: u.id,
          cells: [
            <span key="n" className="font-medium text-ink">{u.full_name ?? "(tanpa nama)"}</span>,
            <div key="c"><div>{u.email ?? "-"}</div><div className="text-xs text-ink/50">{u.phone ?? ""}</div></div>,
            <div key="r" className="flex gap-1">
              {(u.roles ?? []).map((r) => (
                <Badge key={r} label={r === "owner" ? "pemilik" : "pengendara"} cls={r === "owner" ? "bg-okSoft text-ok" : "bg-blueSoft text-blue"} />
              ))}
            </div>,
            u.bookings, u.sos, u.workshops, dateTime(u.created_at),
          ],
        }))}
      />
    </div>
  );
}
