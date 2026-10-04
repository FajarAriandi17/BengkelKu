"use client";

import { useState } from "react";

// DocViewer — menampilkan dokumen sensitif (KTP/selfie) dengan:
// - blur default, reveal manual (tap-and-hold / toggle)
// - watermark email admin
// - TANPA tombol unduh; menu konteks dinonaktifkan
// - jendela lihat singkat (default 120 dtk) lalu otomatis blur lagi
//
// URL gambar HARUS berupa signed URL ≤ 60 dtk yang dibuat server
// (lihat lib/supabase/server.ts + Edge Function admin-signed-doc-url).
export function DocViewer({
  signedUrl,
  watermark,
  viewWindowSec = 120,
}: {
  signedUrl: string;
  watermark: string;
  viewWindowSec?: number;
}) {
  const [revealed, setRevealed] = useState(false);
  const [expired, setExpired] = useState(false);

  function reveal() {
    if (expired) return;
    setRevealed(true);
    window.setTimeout(() => setRevealed(false), viewWindowSec * 1000);
    window.setTimeout(() => setExpired(true), viewWindowSec * 1000);
  }

  return (
    <div
      className="relative overflow-hidden rounded-md border border-blueSoft bg-black/5 select-none"
      onContextMenu={(e) => e.preventDefault()}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={signedUrl}
        alt="dokumen verifikasi"
        draggable={false}
        className={`w-full ${revealed ? "" : "doc-blur revealed-off"} ${
          revealed ? "" : "blur-xl"
        }`}
        style={{ filter: revealed ? "none" : "blur(16px)" }}
      />

      {/* Watermark */}
      <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
        <span className="rotate-[-20deg] text-xl font-bold text-white/40">
          {watermark}
        </span>
      </div>

      {/* Kontrol */}
      <div className="absolute bottom-2 left-2 right-2 flex items-center justify-between">
        {!expired ? (
          <button
            onClick={reveal}
            className="rounded-md bg-blue px-3 py-1.5 text-xs font-semibold text-white"
          >
            {revealed ? "menampilkan…" : "tampilkan dokumen"}
          </button>
        ) : (
          <span className="rounded-md bg-bad/90 px-3 py-1.5 text-xs font-semibold text-white">
            sesi lihat berakhir — minta ulang
          </span>
        )}
        <span className="rounded bg-black/50 px-2 py-1 text-[10px] text-white">
          tanpa unduh · {viewWindowSec}s
        </span>
      </div>
    </div>
  );
}
