import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { canAccess, type AdminRole } from "@/lib/admin-access";

export { canAccess };
export type { AdminRole };

export type AdminMe = { id: string; email: string; full_name: string | null; role: AdminRole };

// Profil admin aktif (null bila bukan admin / sesi tidak ada).
export async function getAdmin(): Promise<AdminMe | null> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_me");
  if (error || !data) return null;
  return data as AdminMe;
}

// Wajib admin; opsional cek akses halaman tertentu.
export async function requireAdmin(href?: string): Promise<AdminMe> {
  const me = await getAdmin();
  if (!me) redirect("/login?error=not_admin");
  if (href && !canAccess(me.role, href)) redirect("/dashboard?error=forbidden");
  return me;
}

export const rupiah = (n: number | null | undefined) =>
  new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(n ?? 0);

export const dateTime = (v: string | null | undefined) =>
  v
    ? new Date(v).toLocaleString("id-ID", {
        timeZone: "Asia/Jakarta", day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit",
      })
    : "-";

export function ago(v: string | null | undefined): string {
  if (!v) return "-";
  const s = Math.max(0, Math.floor((Date.now() - new Date(v).getTime()) / 1000));
  if (s < 60) return `${s} dtk lalu`;
  if (s < 3600) return `${Math.floor(s / 60)} mnt lalu`;
  if (s < 86400) return `${Math.floor(s / 3600)} jam lalu`;
  return `${Math.floor(s / 86400)} hari lalu`;
}
