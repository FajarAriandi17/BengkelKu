"use client";

import { createBrowserClient } from "@supabase/ssr";

// Klien Supabase untuk komponen klien. Hanya memakai anon key (aman di browser).
// JANGAN gunakan service role di sini.
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
