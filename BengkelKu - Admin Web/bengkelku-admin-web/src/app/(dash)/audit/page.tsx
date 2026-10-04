import { createClient } from "@/lib/supabase/server";

// Audit log: jejak aksi admin (verifikasi, akses dokumen, dll.).
export default async function AuditPage() {
  const supabase = createClient();
  const { data: logs } = await supabase
    .from("audit_logs")
    .select("id, actor_id, action, target_type, target_id, created_at")
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-ink">Audit Log</h1>
      <div className="overflow-hidden rounded-lg bg-panel shadow-sm">
        <table className="w-full text-sm">
          <thead className="bg-panel2 text-left text-ink/60">
            <tr>
              <th className="px-4 py-3 font-semibold">Waktu</th>
              <th className="px-4 py-3 font-semibold">Aksi</th>
              <th className="px-4 py-3 font-semibold">Target</th>
              <th className="px-4 py-3 font-semibold">Aktor</th>
            </tr>
          </thead>
          <tbody>
            {(logs ?? []).map((l) => (
              <tr key={l.id} className="border-t border-blueSoft/50">
                <td className="px-4 py-3 text-ink/70">
                  {new Date(l.created_at).toLocaleString("id-ID")}
                </td>
                <td className="px-4 py-3 font-medium text-ink">{l.action}</td>
                <td className="px-4 py-3 text-ink/70">
                  {l.target_type}:{l.target_id?.slice(0, 8)}
                </td>
                <td className="px-4 py-3 text-ink/50">
                  {l.actor_id?.slice(0, 8) ?? "-"}
                </td>
              </tr>
            ))}
            {(!logs || logs.length === 0) && (
              <tr>
                <td colSpan={4} className="px-4 py-10 text-center text-ink/50">
                  belum ada aktivitas.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
