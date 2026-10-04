import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { StatusBadge } from "@/components/StatusBadge";

// Antrean verifikasi: daftar bengkel berstatus 'pending'.
export default async function VerifikasiPage() {
  const supabase = createClient();
  const { data: workshops } = await supabase
    .from("workshops")
    .select("id, name, address, status, created_at")
    .eq("status", "pending")
    .order("created_at", { ascending: true });

  return (
    <div>
      <h1 className="mb-6 text-2xl font-bold text-ink">Verifikasi Bengkel</h1>

      {!workshops || workshops.length === 0 ? (
        <div className="rounded-lg bg-panel p-10 text-center text-ink/50">
          tidak ada antrean verifikasi saat ini.
        </div>
      ) : (
        <div className="overflow-hidden rounded-lg bg-panel shadow-sm">
          <table className="w-full text-sm">
            <thead className="bg-panel2 text-left text-ink/60">
              <tr>
                <th className="px-4 py-3 font-semibold">Nama Bengkel</th>
                <th className="px-4 py-3 font-semibold">Alamat</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Didaftarkan</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {workshops.map((w) => (
                <tr key={w.id} className="border-t border-blueSoft/50">
                  <td className="px-4 py-3 font-medium text-ink">{w.name}</td>
                  <td className="px-4 py-3 text-ink/70">{w.address}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={w.status} />
                  </td>
                  <td className="px-4 py-3 text-ink/60">
                    {new Date(w.created_at).toLocaleDateString("id-ID")}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <Link
                      href={`/verifikasi/${w.id}`}
                      className="rounded-md bg-blue px-3 py-1.5 text-xs font-semibold text-white"
                    >
                      tinjau
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
