import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

// Guard autentikasi untuk SELURUH rute kecuali /login & aset publik.
// Memastikan sesi valid; verifikasi klaim aud=admin dilakukan di layer server/RLS.
export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Rute publik.
  if (
    pathname.startsWith("/login") ||
    pathname.startsWith("/_next") ||
    pathname.startsWith("/favicon") ||
    pathname.startsWith("/api/health")
  ) {
    return NextResponse.next();
  }

  const res = NextResponse.next();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => req.cookies.getAll(),
        setAll: (cookies) =>
          cookies.forEach(({ name, value, options }) =>
            res.cookies.set(name, value, options),
          ),
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const url = req.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }

  // Pastikan ini akun admin (bukan akun mobile). Peran admin disimpan di
  // tabel admin_users; pengecekan penuh dilakukan di server/RLS. Di sini
  // kita cukup pastikan sesi ada; halaman akan menolak non-admin.
  return res;
}

export const config = {
  // Jalankan di semua rute kecuali aset statis.
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
