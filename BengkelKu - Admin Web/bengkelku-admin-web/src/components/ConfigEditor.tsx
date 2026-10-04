"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

// Editor satu kunci app_config (super_admin). Tipe nilai dijaga oleh RPC.
export function ConfigEditor({ configKey, value, editable }: { configKey: string; value: unknown; editable: boolean }) {
  const router = useRouter();
  const initial = typeof value === "string" ? value : JSON.stringify(value);
  const [text, setText] = useState(initial);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  if (!editable) return <code className="break-all text-xs text-ink/80">{initial}</code>;

  async function save() {
    let parsed: unknown;
    if (typeof value === "string") parsed = text;
    else {
      try {
        parsed = JSON.parse(text);
      } catch {
        return setMsg({ ok: false, text: "format tidak valid (harus JSON / angka / true|false)" });
      }
    }
    setSaving(true);
    const { error } = await createClient().rpc("admin_set_config", { p_key: configKey, p_value: parsed });
    setSaving(false);
    if (error) return setMsg({ ok: false, text: error.message });
    setMsg({ ok: true, text: "tersimpan — berlaku di aplikasi" });
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-1">
      <div className="flex gap-2">
        <input aria-label={`nilai ${configKey}`} value={text}
          onChange={(e) => { setText(e.target.value); setMsg(null); }}
          className="min-w-0 flex-1 rounded-md border border-blueSoft bg-panel px-2 py-1.5 font-mono text-xs" />
        <button disabled={text === initial || saving} onClick={save}
          className="rounded-md bg-blue px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-40">
          {saving ? "…" : "simpan"}
        </button>
      </div>
      {msg && <span role={msg.ok ? "status" : "alert"} className={`text-xs ${msg.ok ? "text-ok" : "text-bad"}`}>{msg.text}</span>}
    </div>
  );
}
