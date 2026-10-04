import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { ErrorBox, MapBadge } from "@/components/DataTable";
import { RpcAction } from "@/components/RpcAction";
import { CHAT_REPORT_STATE } from "@/lib/labels";

type Thread = {
  report: { id: string; thread_id: string; reason: string; state: string; created_at: string };
  messages: { id: string; kind: string; body: string | null; created_at: string; role: string }[];
};

// Tinjau percakapan terlapor (RPC mencatat VIEW_REPORTED_CHAT) lalu tindak/abaikan.
export default async function ModerasiDetail({ params }: { params: { id: string } }) {
  await requireAdmin("/moderasi");
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_chat_report_thread", { p_report_id: params.id });
  const t = data as Thread | null;
  if (error || !t) {
    return (
      <div>
        <Link href="/moderasi" className="text-sm text-blue">← kembali</Link>
        <div className="mt-4"><ErrorBox message={error?.message ?? "laporan tidak ditemukan"} /></div>
      </div>
    );
  }
  const open = ["open", "reviewing"].includes(t.report.state);

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <div className="lg:col-span-2">
        <Link href="/moderasi" className="text-sm text-blue">← semua laporan</Link>
        <div className="mt-2 flex items-center gap-2">
          <h1 className="text-2xl font-bold text-ink">Laporan Chat</h1>
          <MapBadge map={CHAT_REPORT_STATE} value={t.report.state} />
        </div>
        <p className="mb-4 mt-1 text-sm text-ink/60">alasan: “{t.report.reason}” · {dateTime(t.report.created_at)}</p>
        <div className="space-y-2 rounded-lg bg-panel p-5 shadow-sm">
          {t.messages.map((m) => (
            <div key={m.id} className={`flex ${m.role === "bengkel" ? "justify-end" : "justify-start"}`}>
              <div className={`max-w-[80%] rounded-lg px-3 py-2 text-sm ${m.role === "bengkel" ? "bg-blueSoft text-ink" : "bg-panel2 text-ink"}`}>
                <div className="mb-0.5 text-[10px] font-semibold uppercase text-ink/40">{m.role} · {m.kind}</div>
                <div className="whitespace-pre-wrap">{m.kind === "image" ? "[gambar]" : m.body}</div>
                <div className="mt-1 text-[10px] text-ink/40">{dateTime(m.created_at)}</div>
              </div>
            </div>
          ))}
          {t.messages.length === 0 && <p className="text-sm text-ink/50">percakapan kosong.</p>}
        </div>
      </div>
      <aside>
        {open ? (
          <div className="sticky top-6 space-y-4 rounded-lg bg-panel p-5 shadow-sm">
            <h2 className="font-semibold text-ink">Keputusan</h2>
            <RpcAction rpc="admin_chat_report_resolve" args={{ p_report_id: t.report.id, p_action: "actioned", p_close_thread: true }}
              fields={[{ name: "p_note", label: "catatan tindakan", type: "textarea", required: true, minLength: 5 }]}
              label="tindak & kunci percakapan" tone="danger"
              confirmText="Kunci percakapan ini (jadi hanya-baca untuk kedua pihak)?" successText="laporan ditindak" />
            <RpcAction rpc="admin_chat_report_resolve" args={{ p_report_id: t.report.id, p_action: "actioned", p_close_thread: false }}
              fields={[{ name: "p_note", label: "catatan peringatan", type: "textarea", required: true, minLength: 5 }]}
              label="tindak tanpa mengunci" tone="ghost" successText="laporan ditindak" />
            <RpcAction rpc="admin_chat_report_resolve" args={{ p_report_id: t.report.id, p_action: "dismissed", p_close_thread: false }}
              fields={[{ name: "p_note", label: "alasan diabaikan", type: "textarea" }]}
              label="abaikan laporan" tone="ghost" successText="laporan diabaikan" />
          </div>
        ) : (
          <div className="rounded-lg bg-panel p-5 text-sm text-ink/60 shadow-sm">laporan sudah diputuskan.</div>
        )}
      </aside>
    </div>
  );
}
