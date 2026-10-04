"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

// Memuat ulang data server component secara berkala (mis. monitor SOS).
export function AutoRefresh({ seconds = 10 }: { seconds?: number }) {
  const router = useRouter();
  const [paused, setPaused] = useState(false);
  useEffect(() => {
    if (paused) return;
    const t = window.setInterval(() => router.refresh(), seconds * 1000);
    return () => window.clearInterval(t);
  }, [router, seconds, paused]);
  return (
    <button onClick={() => setPaused((p) => !p)} className="rounded-md border border-blueSoft bg-panel px-3 py-1.5 text-xs font-medium text-ink">
      {paused ? "▶ lanjutkan auto-refresh" : `⏸ auto-refresh ${seconds} dtk`}
    </button>
  );
}
