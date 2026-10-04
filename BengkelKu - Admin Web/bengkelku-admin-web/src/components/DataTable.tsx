import type { ReactNode } from "react";

export function PageTitle({ title, subtitle, right }: { title: string; subtitle?: string; right?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-bold text-ink">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-ink/60">{subtitle}</p>}
      </div>
      {right}
    </div>
  );
}

export function ErrorBox({ message }: { message?: string | null }) {
  if (!message) return null;
  return (
    <div role="alert" className="mb-4 rounded-md border border-bad/30 bg-badSoft px-4 py-3 text-sm text-bad">
      gagal memuat data: {message}
    </div>
  );
}

export function Badge({ label, cls }: { label: string; cls: string }) {
  return <span className={`inline-flex whitespace-nowrap rounded-pill px-2.5 py-0.5 text-xs font-semibold ${cls}`}>{label}</span>;
}

export function MapBadge({ map, value }: { map: Record<string, { label: string; cls: string }>; value: string }) {
  const m = map[value] ?? { label: value.toLowerCase(), cls: "bg-blueSoft text-blue" };
  return <Badge label={m.label} cls={m.cls} />;
}

export function DataTable({
  head,
  rows,
  empty = "belum ada data.",
}: {
  head: string[];
  rows: { key: string; cells: ReactNode[]; highlight?: boolean }[];
  empty?: string;
}) {
  return (
    <div className="overflow-x-auto rounded-lg bg-panel shadow-sm">
      <table className="w-full text-sm">
        <thead className="bg-panel2 text-left text-ink/60">
          <tr>
            {head.map((h, i) => (
              <th key={i} scope="col" className="whitespace-nowrap px-4 py-3 font-semibold">{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.key} className={`border-t border-blueSoft/50 align-top ${r.highlight ? "bg-badSoft/40" : ""}`}>
              {r.cells.map((c, i) => (
                <td key={i} className="px-4 py-3 text-ink/80">{c}</td>
              ))}
            </tr>
          ))}
          {rows.length === 0 && (
            <tr>
              <td colSpan={head.length} className="px-4 py-10 text-center text-ink/50">{empty}</td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

export function StatCard({ label, value, href, tone = "blue" }: { label: string; value: ReactNode; href?: string; tone?: "blue" | "bad" | "ok" | "warn" }) {
  const color = { blue: "text-blue", bad: "text-bad", ok: "text-ok", warn: "text-warn" }[tone];
  const body = (
    <>
      <div className={`text-3xl font-extrabold ${color}`}>{value}</div>
      <div className="mt-1 text-sm text-ink/60">{label}</div>
    </>
  );
  return href ? (
    <a href={href} className="rounded-lg bg-panel p-5 shadow-sm transition hover:ring-2 hover:ring-blueSoft">{body}</a>
  ) : (
    <div className="rounded-lg bg-panel p-5 shadow-sm">{body}</div>
  );
}
