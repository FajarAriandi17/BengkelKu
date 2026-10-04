import { AdminShell } from "@/components/AdminShell";
import { requireAdmin } from "@/lib/admin";

export const dynamic = "force-dynamic";

// Semua halaman admin wajib akun di admin_users yang aktif.
export default async function DashLayout({ children }: { children: React.ReactNode }) {
  const me = await requireAdmin();
  return (
    <AdminShell role={me.role} email={me.email} name={me.full_name}>
      {children}
    </AdminShell>
  );
}
