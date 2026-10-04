// Matriks akses halaman per peran admin. super_admin selalu boleh.
export type AdminRole = "super_admin" | "verifikator" | "finance" | "cs";

export const ROLE_LABEL: Record<AdminRole, string> = {
  super_admin: "Super Admin",
  verifikator: "Verifikator",
  finance: "Finance",
  cs: "Customer Service",
};

export const ACCESS: Record<string, AdminRole[]> = {
  "/dashboard": ["verifikator", "finance", "cs"],
  "/verifikasi": ["verifikator"],
  "/bengkel": ["verifikator", "cs"],
  "/pengguna": ["cs", "verifikator"],
  "/darurat": ["cs"],
  "/bantuan": ["cs"],
  "/moderasi": ["cs"],
  "/transaksi": ["finance", "cs"],
  "/payout": ["finance"],
  "/laporan": ["finance"],
  "/konfigurasi": ["verifikator", "finance", "cs"],
  "/audit": [],
  "/tim": [],
};

export function canAccess(role: AdminRole | null | undefined, href: string): boolean {
  if (!role) return false;
  if (role === "super_admin") return true;
  const key = Object.keys(ACCESS).find((k) => href === k || href.startsWith(k + "/"));
  if (!key) return false;
  return ACCESS[key].includes(role);
}
