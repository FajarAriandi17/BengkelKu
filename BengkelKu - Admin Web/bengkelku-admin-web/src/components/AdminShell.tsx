"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { canAccess, ROLE_LABEL, type AdminRole } from "@/lib/admin-access";

const GROUPS: { title: string; items: { href: string; label: string }[] }[] = [
  { title: "Ringkasan", items: [{ href: "/dashboard", label: "Dashboard" }] },
  {
    title: "Mitra & Pengguna",
    items: [
      { href: "/verifikasi", label: "Verifikasi Bengkel" },
      { href: "/bengkel", label: "Bengkel" },
      { href: "/pengguna", label: "Pengguna" },
    ],
  },
  {
    title: "Operasional",
    items: [
      { href: "/darurat", label: "Darurat (SOS) Live" },
      { href: "/bantuan", label: "Tiket Bantuan" },
      { href: "/moderasi", label: "Moderasi Chat" },
    ],
  },
  {
    title: "Keuangan",
    items: [
      { href: "/transaksi", label: "Transaksi" },
      { href: "/payout", label: "Payout" },
      { href: "/laporan", label: "Laporan" },
    ],
  },
  {
    title: "Sistem",
    items: [
      { href: "/konfigurasi", label: "Konfigurasi" },
      { href: "/audit", label: "Audit Log" },
      { href: "/tim", label: "Tim Admin" },
    ],
  },
];

// Kerangka layout admin: sidebar (difilter per peran) + topbar.
export function AdminShell({
  children,
  role,
  email,
  name,
}: {
  children: React.ReactNode;
  role: AdminRole;
  email: string;
  name: string | null;
}) {
  const pathname = usePathname();

  async function logout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/login";
  }

  return (
    <div className="flex min-h-screen bg-panel2">
      <aside className="sticky top-0 h-screen w-64 shrink-0 overflow-y-auto border-r border-blueSoft bg-panel p-4">
        <div className="mb-6 px-2 text-lg font-extrabold text-blue">
          BengkelKu<span className="text-ink"> Admin</span>
        </div>
        <nav aria-label="Navigasi admin" className="space-y-5">
          {GROUPS.map((g) => {
            const items = g.items.filter((i) => canAccess(role, i.href));
            if (items.length === 0) return null;
            return (
              <div key={g.title}>
                <div className="mb-1 px-3 text-[11px] font-semibold uppercase tracking-wide text-ink/40">
                  {g.title}
                </div>
                <div className="space-y-0.5">
                  {items.map((item) => {
                    const active = pathname === item.href || pathname.startsWith(item.href + "/");
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        aria-current={active ? "page" : undefined}
                        className={`block rounded-md px-3 py-2 text-sm font-medium transition-colors duration-150 ${
                          active ? "bg-blueSoft text-blue" : "text-ink/70 hover:bg-panel2"
                        }`}
                      >
                        {item.label}
                      </Link>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-blueSoft bg-panel px-6 py-3">
          <div className="text-sm text-ink/60">
            <span className="font-semibold text-ink">{name || email}</span>
            <span className="ml-2 rounded-pill bg-blueSoft px-2 py-0.5 text-xs font-semibold text-blue">
              {ROLE_LABEL[role]}
            </span>
          </div>
          <button
            onClick={logout}
            className="rounded-md border border-blueSoft px-3 py-1.5 text-sm font-medium text-ink hover:bg-panel2"
          >
            keluar
          </button>
        </header>
        <main className="min-w-0 flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}
