"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

// Login admin: username (email) + kata sandi. Tanpa signup publik.
// 2FA TOTP diverifikasi setelah password (langkah kedua) — lihat docs/ARCHITECTURE.md.
export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Akun aplikasi (bukan admin) diarahkan ke sini → keluarkan sesi & beri tahu.
  useEffect(() => {
    if (params.get("error") === "not_admin") {
      createClient().auth.signOut();
      setError("akun ini tidak terdaftar sebagai admin aktif.");
    }
  }, [params]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    setLoading(false);
    if (error) {
      setError("username atau kata sandi salah.");
      return;
    }
    const next = params.get("next");
    router.replace(next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard");
    router.refresh();
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-panel2 p-6">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-sm rounded-lg bg-panel p-8 shadow-sm"
      >
        <h1 className="text-xl font-bold text-ink">BengkelKu Admin</h1>
        <p className="mb-6 mt-1 text-sm text-ink/60">
          masuk untuk mengelola verifikasi, operasional, dan keuangan.
        </p>

        <label htmlFor="email" className="mb-1 block text-sm font-semibold">username (email)</label>
        <input
          id="email"
          autoComplete="username"
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-4 w-full rounded-md border border-blueSoft bg-panel px-3 py-2 outline-none focus:border-blue"
        />

        <label htmlFor="password" className="mb-1 block text-sm font-semibold">kata sandi</label>
        <input
          id="password"
          autoComplete="current-password"
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-4 w-full rounded-md border border-blueSoft bg-panel px-3 py-2 outline-none focus:border-blue"
        />

        {error && <p role="alert" className="mb-4 text-sm text-bad">{error}</p>}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-md bg-blue py-2.5 font-semibold text-white transition disabled:opacity-50"
        >
          {loading ? "memproses…" : "masuk"}
        </button>
        <p className="mt-4 text-center text-xs text-ink/50">
          akun hanya dibuat lewat undangan admin.
        </p>
      </form>
    </main>
  );
}
