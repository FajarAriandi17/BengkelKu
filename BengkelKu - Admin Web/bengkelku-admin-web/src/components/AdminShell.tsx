"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

const NAV = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/verifikasi", label: "Verifikasi Bengkel" },
  { href: "/bengkel", label: "Bengkel" },
  { href: "/pengguna", label: "Pengguna" },
  { href: "/transaksi", label: "Transaksi" },
  { href: "/payout", label: "Payout" },
  { href: "/moderasi", label: "Moderasi" },
  { href: "/konfigurasi", label: "Konfigurasi" },
  { href: "/laporan", label: "Laporan" },
  { href: "/audit", label: "Audit Log" },
  { href: "/tim", label: "Tim Admin" },
];

// Kerangka layout admin: sidebar + topbar. Desktop-first (min 1024px).
export function AdminShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  async function logout() {
    const supabase = createClient();
    await supabase.auth.signOut();
    window.location.href = "/login";
  }

  return (
    <div className="flex min-h-screen bg-panel2">
      <aside className="w-64 shrink-0 border-r border-blueSoft bg-panel p-4">
        <div className="mb-6 px-2 text-lg font-extrabold text-blue">
          BengkelKu<span className="text-ink"> Admin</span>
        </div>
        <nav className="space-y-1">
          {NAV.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`block rounded-md px-3 py-2 text-sm font-medium transition ${
                  active
                    ? "bg-blueSoft text-blue"
                    : "text-ink/70 hover:bg-panel2"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-blueSoft bg-panel px-6 py-3">
          <div className="text-sm text-ink/60">panel admin internal</div>
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
