"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Field = {
  name: string;
  label: string;
  type?: "text" | "textarea" | "select";
  options?: { value: string; label: string }[];
  required?: boolean;
  minLength?: number;
  placeholder?: string;
  defaultValue?: string;
};

// Tombol aksi admin yang memanggil RPC Supabase dengan sesi admin sendiri
// (cek peran + audit dilakukan di database). Bisa memiliki form kecil.
export function RpcAction({
  rpc, args, fields = [], label, confirmText, tone = "primary", successText = "tersimpan", redirectTo,
}: {
  rpc: string;
  args: Record<string, unknown>;
  fields?: Field[];
  label: string;
  confirmText?: string;
  tone?: "primary" | "danger" | "ok" | "ghost";
  successText?: string;
  redirectTo?: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [values, setValues] = useState<Record<string, string>>(
    Object.fromEntries(fields.map((f) => [f.name, f.defaultValue ?? f.options?.[0]?.value ?? ""])),
  );
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const cls = {
    primary: "bg-blue text-white",
    danger: "bg-bad text-white",
    ok: "bg-ok text-white",
    ghost: "border border-blueSoft text-ink",
  }[tone];

  async function run() {
    for (const f of fields) {
      const v = (values[f.name] ?? "").trim();
      if (f.required && !v) return setError(`${f.label} wajib diisi`);
      if (f.minLength && v.length < f.minLength) return setError(`${f.label} minimal ${f.minLength} karakter`);
    }
    if (confirmText && !window.confirm(confirmText)) return;
    setLoading(true);
    setError(null);
    const payload: Record<string, unknown> = { ...args };
    for (const f of fields) payload[f.name] = (values[f.name] ?? "").trim() || null;
    const { error } = await createClient().rpc(rpc, payload);
    setLoading(false);
    if (error) return setError(error.message);
    setDone(true);
    setOpen(false);
    if (redirectTo) router.push(redirectTo);
    router.refresh();
    window.setTimeout(() => setDone(false), 2500);
  }

  const btn = (
    <button disabled={loading} onClick={run}
      className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-opacity disabled:opacity-50 ${cls}`}>
      {loading ? "memproses…" : label}
    </button>
  );

  if (fields.length === 0) {
    return (
      <span className="inline-flex flex-col items-start gap-1">
        {btn}
        {error && <span role="alert" className="text-xs text-bad">{error}</span>}
        {done && <span className="text-xs text-ok">{successText}</span>}
      </span>
    );
  }

  const inputCls = "mt-1 w-full rounded-md border border-blueSoft bg-panel px-2 py-1.5 text-sm font-normal text-ink";
  return (
    <div className="w-full">
      {!open ? (
        <button onClick={() => setOpen(true)} className={`rounded-md px-3 py-1.5 text-xs font-semibold ${cls}`}>{label}</button>
      ) : (
        <div className="space-y-2 rounded-md border border-blueSoft bg-panel p-3">
          {fields.map((f) => (
            <label key={f.name} className="block text-xs font-semibold text-ink/70">
              {f.label}
              {f.type === "textarea" ? (
                <textarea value={values[f.name]} placeholder={f.placeholder}
                  onChange={(e) => setValues((p) => ({ ...p, [f.name]: e.target.value }))} className={`${inputCls} h-20`} />
              ) : f.type === "select" ? (
                <select value={values[f.name]} onChange={(e) => setValues((p) => ({ ...p, [f.name]: e.target.value }))} className={inputCls}>
                  {f.options?.map((o) => (<option key={o.value} value={o.value}>{o.label}</option>))}
                </select>
              ) : (
                <input value={values[f.name]} placeholder={f.placeholder}
                  onChange={(e) => setValues((p) => ({ ...p, [f.name]: e.target.value }))} className={inputCls} />
              )}
            </label>
          ))}
          {error && <p role="alert" className="text-xs text-bad">{error}</p>}
          <div className="flex gap-2">
            {btn}
            <button onClick={() => { setOpen(false); setError(null); }} className="rounded-md border border-blueSoft px-3 py-1.5 text-xs">batal</button>
          </div>
        </div>
      )}
      {done && <p className="mt-1 text-xs text-ok">{successText}</p>}
    </div>
  );
}
