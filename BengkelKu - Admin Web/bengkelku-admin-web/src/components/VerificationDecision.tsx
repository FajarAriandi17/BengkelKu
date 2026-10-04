"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { REJECT_REASONS } from "@/lib/theme/tokens";

const CHECKLIST = [
  { key: "ktp_clear", label: "KTP jelas & terbaca" },
  { key: "selfie_match", label: "Wajah selfie cocok dengan KTP" },
  { key: "name_match", label: "Nama cocok dengan pendaftaran" },
  { key: "location_match", label: "Foto lokasi sesuai pin peta" },
];

// Panel keputusan verifikasi: checklist 4 item + setujui/tolak (dengan alasan).
export function VerificationDecision({ workshopId }: { workshopId: string }) {
  const router = useRouter();
  const [checks, setChecks] = useState<Record<string, boolean>>({});
  const [mode, setMode] = useState<"idle" | "reject">("idle");
  const [reasonCode, setReasonCode] = useState(REJECT_REASONS[0].code);
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const allChecked = CHECKLIST.every((c) => checks[c.key]);

  async function submit(decision: "approve" | "reject") {
    setLoading(true);
    setError(null);
    const res = await fetch("/api/verify", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        workshopId,
        decision,
        checklist: checks,
        reasonCode: decision === "reject" ? reasonCode : null,
        note: note || null,
      }),
    });
    setLoading(false);
    if (!res.ok) {
      setError("gagal menyimpan keputusan. coba lagi.");
      return;
    }
    router.push("/verifikasi");
    router.refresh();
  }

  return (
    <div className="sticky top-6 rounded-lg bg-panel p-5 shadow-sm">
      <h2 className="mb-3 font-semibold text-ink">Keputusan</h2>

      <div className="mb-4 space-y-2">
        {CHECKLIST.map((c) => (
          <label key={c.key} className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={!!checks[c.key]}
              onChange={(e) =>
                setChecks((p) => ({ ...p, [c.key]: e.target.checked }))
              }
            />
            <span className="text-ink/80">{c.label}</span>
          </label>
        ))}
      </div>

      {error && <p className="mb-3 text-sm text-bad">{error}</p>}

      {mode === "idle" ? (
        <div className="space-y-2">
          <button
            disabled={!allChecked || loading}
            onClick={() => submit("approve")}
            className="w-full rounded-md bg-ok py-2.5 text-sm font-semibold text-white disabled:opacity-50"
          >
            setujui & tayangkan
          </button>
          <button
            disabled={loading}
            onClick={() => setMode("reject")}
            className="w-full rounded-md border border-bad py-2.5 text-sm font-semibold text-bad"
          >
            tolak
          </button>
          {!allChecked && (
            <p className="text-xs text-ink/50">
              centang semua item untuk menyetujui.
            </p>
          )}
        </div>
      ) : (
        <div className="space-y-3">
          <label className="block text-sm font-semibold">alasan penolakan</label>
          <select
            value={reasonCode}
            onChange={(e) => setReasonCode(e.target.value as typeof reasonCode)}
            className="w-full rounded-md border border-blueSoft bg-panel px-3 py-2 text-sm"
          >
            {REJECT_REASONS.map((r) => (
              <option key={r.code} value={r.code}>
                {r.label}
              </option>
            ))}
          </select>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="catatan untuk pemilik bengkel (opsional)"
            className="h-24 w-full rounded-md border border-blueSoft bg-panel px-3 py-2 text-sm"
          />
          <div className="flex gap-2">
            <button
              disabled={loading}
              onClick={() => submit("reject")}
              className="flex-1 rounded-md bg-bad py-2.5 text-sm font-semibold text-white disabled:opacity-50"
            >
              kirim penolakan
            </button>
            <button
              onClick={() => setMode("idle")}
              className="rounded-md border border-blueSoft px-3 py-2.5 text-sm"
            >
              batal
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
