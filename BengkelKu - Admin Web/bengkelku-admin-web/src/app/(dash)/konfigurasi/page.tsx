import { createClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { ErrorBox, PageTitle } from "@/components/DataTable";
import { ConfigEditor } from "@/components/ConfigEditor";

function groupOf(key: string) {
  if (key.startsWith("sos_")) return "Darurat (SOS)";
  if (key.startsWith("booking_") || key.startsWith("payment_") || key.includes("commission") || key.includes("refund")) return "Booking & Pembayaran";
  if (key.startsWith("chat_")) return "Chat";
  if (key.startsWith("oil_")) return "Pengingat Oli";
  if (key.startsWith("support_")) return "Bantuan";
  return "Umum";
}

// Konfigurasi aplikasi (tabel app_config) — dibaca langsung oleh aplikasi mobile.
export default async function KonfigurasiPage() {
  const me = await requireAdmin("/konfigurasi");
  const supabase = createClient();
  const { data, error } = await supabase.from("app_config").select("key, value, label, updated_at").order("key");
  const editable = me.role === "super_admin";

  const groups = new Map<string, NonNullable<typeof data>>();
  for (const row of data ?? []) {
    const g = groupOf(row.key);
    groups.set(g, [...(groups.get(g) ?? []), row]);
  }

  return (
    <div>
      <PageTitle
        title="Konfigurasi"
        subtitle={editable ? "perubahan langsung berlaku di aplikasi & tercatat di audit log." : "hanya super admin yang dapat mengubah konfigurasi."}
      />
      <ErrorBox message={error?.message} />
      <div className="space-y-6">
        {[...groups.entries()].map(([g, rows]) => (
          <section key={g} className="rounded-lg bg-panel p-5 shadow-sm">
            <h2 className="mb-3 font-semibold text-ink">{g}</h2>
            <div className="divide-y divide-blueSoft/50">
              {rows.map((r) => (
                <div key={r.key} className="grid grid-cols-1 gap-2 py-3 md:grid-cols-[1fr_320px]">
                  <div>
                    <div className="text-sm font-medium text-ink">{r.label}</div>
                    <div className="font-mono text-xs text-ink/40">{r.key} · diubah {dateTime(r.updated_at)}</div>
                  </div>
                  <ConfigEditor configKey={r.key} value={r.value} editable={editable} />
                </div>
              ))}
            </div>
          </section>
        ))}
        {(data ?? []).length === 0 && !error && <p className="text-sm text-ink/50">belum ada konfigurasi (jalankan migrasi 0010).</p>}
      </div>
    </div>
  );
}
