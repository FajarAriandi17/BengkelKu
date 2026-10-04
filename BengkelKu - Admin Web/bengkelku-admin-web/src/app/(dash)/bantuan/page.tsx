import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { ago, requireAdmin } from "@/lib/admin";
import { DataTable, ErrorBox, MapBadge, PageTitle } from "@/components/DataTable";
import { TICKET_CATEGORY, TICKET_STATE } from "@/lib/labels";

// Tiket bantuan dari Pusat Bantuan aplikasi (pengendara & pemilik bengkel).
export default async function BantuanPage({ searchParams }: { searchParams: { state?: string } }) {
  await requireAdmin("/bantuan");
  const supabase = createClient();
  const state = searchParams.state ?? "open";
  let q = supabase
    .from("support_tickets")
    .select("id, code, category, description, state, created_at, booking_id, sos_request_id, user:users!support_tickets_user_id_fkey(full_name)")
    .order("created_at", { ascending: true })
    .limit(200);
  if (state === "open") q = q.neq("state", "SELESAI");
  else if (state !== "all") q = q.eq("state", state);
  const { data, error } = await q;
  type Row = {
    id: string; code: string; category: string; description: string; state: string; created_at: string;
    booking_id: string | null; sos_request_id: string | null; user: { full_name: string | null } | null;
  };
  const rows = (data ?? []) as unknown as Row[];
  const tabs = [
    { v: "open", l: "terbuka" }, { v: "DITERIMA", l: "baru" }, { v: "MENUNGGU_INFO", l: "menunggu info" },
    { v: "SELESAI", l: "selesai" }, { v: "all", l: "semua" },
  ];

  return (
    <div>
      <PageTitle title="Tiket Bantuan" subtitle="balasan & keputusan admin langsung muncul di aplikasi pelapor (notifikasi + detail tiket)." />
      <div className="mb-4 flex flex-wrap gap-2" role="tablist">
        {tabs.map((t) => (
          <Link key={t.v} href={`/bantuan?state=${t.v}`} role="tab" aria-selected={state === t.v}
            className={`rounded-pill px-3 py-1.5 text-xs font-semibold ${state === t.v ? "bg-blue text-white" : "bg-panel text-ink/70"}`}>
            {t.l}
          </Link>
        ))}
      </div>
      <ErrorBox message={error?.message} />
      <DataTable
        head={["Kode", "Kategori", "Pelapor", "Ringkasan", "Status", "Dibuat", ""]}
        empty="tidak ada tiket."
        rows={rows.map((t) => ({
          key: t.id,
          cells: [
            <span key="c" className="font-mono font-semibold">{t.code}</span>,
            <div key="k">
              <div>{TICKET_CATEGORY[t.category] ?? t.category}</div>
              <div className="text-xs text-ink/50">{t.sos_request_id ? "terkait SOS" : t.booking_id ? "terkait booking" : ""}</div>
            </div>,
            t.user?.full_name ?? "-",
            <span key="d" className="line-clamp-2 max-w-xs">{t.description}</span>,
            <MapBadge key="s" map={TICKET_STATE} value={t.state} />,
            ago(t.created_at),
            <Link key="l" href={`/bantuan/${t.id}`} className="rounded-md bg-blue px-3 py-1.5 text-xs font-semibold text-white">buka</Link>,
          ],
        }))}
      />
    </div>
  );
}
