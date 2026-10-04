import { AdminShell } from "@/components/AdminShell";

// Layout untuk seluruh halaman admin (dibungkus AdminShell).
// Middleware sudah memastikan sesi; pengecekan peran dilakukan per halaman/RLS.
export default function DashLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <AdminShell>{children}</AdminShell>;
}
