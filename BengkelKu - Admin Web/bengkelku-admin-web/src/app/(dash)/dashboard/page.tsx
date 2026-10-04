import { createClient } from "@/lib/supabase/server";

// Dashboard: ringkasan antrean verifikasi & metrik singkat.
export default async function DashboardPage() {
  const supabase = createClient();

  const [{ count: pending }, { count: verified }] = await Promise.all([
    supabase.from("workshops").select("*", { count: "exact", head: true }).eq("status", "pending"),
    supabase.from("workshops").select("*", { count: "exact", head: true }).eq("status", "verified"),
  ]);

  const cards = [
    { label: "menunggu verifikasi", value: pending ?? 0, href: "/verifikasi" },
    { label: "bengkel tayang", value: verified ?? 0, href: "/bengkel" },
  ];

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-ink">Dashboard</h1>
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {cards.map((c) => (
          <a
            key={c.label}
            href={c.href}
            className="rounded-lg bg-panel p-5 shadow-sm transition hover:ring-2 hover:ring-blueSoft"
          >
            <div className="text-3xl font-extrabold text-blue">{c.value}</div>
            <div className="mt-1 text-sm text-ink/60">{c.label}</div>
          </a>
        ))}
      </div>
      <p className="mt-8 text-sm text-ink/50">
        pilih “Verifikasi Bengkel” untuk meninjau antrean pendaftaran.
      </p>
    </div>
  );
}
