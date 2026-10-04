import { createClient } from "@/lib/supabase/server";
import { canAccess, requireAdmin } from "@/lib/admin";
import { ErrorBox, PageTitle, StatCard } from "@/components/DataTable";

type Stats = Record<string, number>;

// Dashboard: metrik real-time dari admin_dashboard_stats (difilter per peran).
export default async function DashboardPage({ searchParams }: { searchParams: { error?: string } }) {
  const me = await requireAdmin("/dashboard");
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_dashboard_stats");
  const s = (data ?? {}) as Stats;

  const cards: { label: string; key: string; href: string; tone?: "blue" | "bad" | "ok" | "warn" }[] = [
    { label: "menunggu verifikasi", key: "pending_workshops", href: "/verifikasi", tone: "warn" },
    { label: "bengkel tayang", key: "verified_workshops", href: "/bengkel", tone: "ok" },
    { label: "bengkel disuspensi", key: "suspended_workshops", href: "/bengkel?status=suspended", tone: "bad" },
    { label: "pengguna terdaftar", key: "users", href: "/pengguna" },
    { label: "booking hari ini", key: "bookings_today", href: "/transaksi" },
    { label: "SOS aktif", key: "sos_active", href: "/darurat" },
    { label: "SOS > 3 mnt tanpa bengkel", key: "sos_unanswered", href: "/darurat", tone: "bad" },
    { label: "bengkel siaga online", key: "standby_ready", href: "/darurat", tone: "ok" },
    { label: "tiket bantuan terbuka", key: "tickets_open", href: "/bantuan", tone: "warn" },
    { label: "laporan chat terbuka", key: "chat_reports_open", href: "/moderasi", tone: "bad" },
  ];
  const visible = cards.filter((c) => canAccess(me.role, c.href.split("?")[0]));

  return (
    <div>
      <PageTitle title="Dashboard" subtitle={`halo, ${me.full_name || me.email}. ringkasan operasional BengkelKu saat ini.`} />
      {searchParams.error === "forbidden" && (
        <div role="alert" className="mb-4 rounded-md bg-warnSoft px-4 py-3 text-sm text-warn">
          peranmu tidak memiliki akses ke halaman tersebut.
        </div>
      )}
      <ErrorBox message={error?.message} />
      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-5">
        {visible.map((c) => (
          <StatCard key={c.key} label={c.label} value={s[c.key] ?? 0} href={c.href} tone={c.tone} />
        ))}
      </div>
    </div>
  );
}
