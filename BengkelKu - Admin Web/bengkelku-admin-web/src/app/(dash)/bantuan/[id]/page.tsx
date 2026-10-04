import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient, createAdminClient } from "@/lib/supabase/server";
import { dateTime, requireAdmin } from "@/lib/admin";
import { MapBadge } from "@/components/DataTable";
import { RpcAction } from "@/components/RpcAction";
import { TICKET_CATEGORY, TICKET_STATE } from "@/lib/labels";

// Detail tiket: deskripsi, foto (signed URL), percakapan, balas / minta info / selesaikan.
export default async function TicketDetail({ params }: { params: { id: string } }) {
  await requireAdmin("/bantuan");
  const supabase = createClient();
  const { data: t } = await supabase
    .from("support_tickets")
    .select("id, code, category, description, photos, state, decision, decision_reason, booking_id, sos_request_id, thread_id, created_at, user:users!support_tickets_user_id_fkey(full_name, phone, roles)")
    .eq("id", params.id)
    .maybeSingle();
  if (!t) notFound();
  const ticket = t as unknown as {
    id: string; code: string; category: string; description: string; photos: string[]; state: string;
    decision: string | null; decision_reason: string | null; booking_id: string | null; sos_request_id: string | null;
    thread_id: string | null; created_at: string; user: { full_name: string | null; phone: string | null; roles: string[] } | null;
  };

  const [{ data: msgs }, { data: audit }] = await Promise.all([
    supabase.from("support_messages").select("id, from_admin, body, created_at").eq("ticket_id", params.id).order("created_at"),
    supabase.from("audit_logs").select("id, action, created_at").eq("target_type", "support_ticket").eq("target_id", params.id)
      .order("created_at", { ascending: false }).limit(20),
  ]);

  const admin = createAdminClient();
  const photos = (await Promise.all(
    (ticket.photos ?? []).map(async (p) => {
      const { data } = await admin.storage.from("support-photos").createSignedUrl(p, 300);
      return data?.signedUrl ?? "";
    }),
  )).filter(Boolean);
  const closed = ticket.state === "SELESAI";

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
      <div className="space-y-6 lg:col-span-2">
        <div>
          <Link href="/bantuan" className="text-sm text-blue">← semua tiket</Link>
          <div className="mt-2 flex flex-wrap items-center gap-2">
            <h1 className="font-mono text-2xl font-bold text-ink">{ticket.code}</h1>
            <MapBadge map={TICKET_STATE} value={ticket.state} />
          </div>
          <p className="mt-1 text-sm text-ink/60">
            {TICKET_CATEGORY[ticket.category] ?? ticket.category} · {ticket.user?.full_name ?? "-"}
            {ticket.user?.roles?.includes("owner") ? " (pemilik bengkel)" : " (pengendara)"} · {dateTime(ticket.created_at)}
          </p>
        </div>
        <section className="rounded-lg bg-panel p-5 shadow-sm">
          <h2 className="mb-2 font-semibold text-ink">Laporan</h2>
          <p className="whitespace-pre-wrap text-sm text-ink/80">{ticket.description}</p>
          {photos.length > 0 && (
            <div className="mt-4 grid grid-cols-3 gap-3">
              {photos.map((u, i) => (
                <a key={i} href={u} target="_blank" rel="noreferrer">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={u} alt={`foto bukti ${i + 1}`} className="h-32 w-full rounded-md object-cover" />
                </a>
              ))}
            </div>
          )}
          <dl className="mt-4 grid grid-cols-[120px_1fr] gap-y-1 text-xs text-ink/60">
            {ticket.booking_id && (<><dt>Booking</dt><dd className="font-mono">{ticket.booking_id.slice(0, 8)}</dd></>)}
            {ticket.sos_request_id && (<><dt>SOS</dt><dd className="font-mono">{ticket.sos_request_id.slice(0, 8)}</dd></>)}
            {ticket.thread_id && (<><dt>Chat</dt><dd className="font-mono">{ticket.thread_id.slice(0, 8)}</dd></>)}
          </dl>
        </section>
        <section className="rounded-lg bg-panel p-5 shadow-sm">
          <h2 className="mb-3 font-semibold text-ink">Percakapan</h2>
          <div className="space-y-3">
            {(msgs ?? []).map((m) => (
              <div key={m.id} className={`flex ${m.from_admin ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[80%] rounded-lg px-3 py-2 text-sm ${m.from_admin ? "bg-blue text-white" : "bg-panel2 text-ink"}`}>
                  <div className="whitespace-pre-wrap">{m.body}</div>
                  <div className={`mt-1 text-[10px] ${m.from_admin ? "text-white/70" : "text-ink/40"}`}>
                    {m.from_admin ? "tim BengkelKu" : "pelapor"} · {dateTime(m.created_at)}
                  </div>
                </div>
              </div>
            ))}
            {(msgs ?? []).length === 0 && <p className="text-sm text-ink/50">belum ada balasan.</p>}
          </div>
        </section>
        {closed && (
          <section className="rounded-lg bg-okSoft p-5 text-sm text-ok">
            <div className="font-semibold">Keputusan: {ticket.decision}</div>
            <div>{ticket.decision_reason}</div>
          </section>
        )}
      </div>
      <aside className="space-y-4">
        {!closed ? (
          <div className="sticky top-6 space-y-4 rounded-lg bg-panel p-5 shadow-sm">
            <h2 className="font-semibold text-ink">Tindakan</h2>
            <RpcAction rpc="admin_ticket_reply" args={{ p_ticket_id: ticket.id }}
              fields={[{ name: "p_body", label: "balasan untuk pelapor", type: "textarea", required: true }]}
              label="kirim balasan" successText="balasan terkirim ke aplikasi" />
            <RpcAction rpc="admin_ticket_reply" args={{ p_ticket_id: ticket.id, p_new_state: "MENUNGGU_INFO" }}
              fields={[{ name: "p_body", label: "info apa yang dibutuhkan?", type: "textarea", required: true }]}
              label="minta info tambahan" tone="ghost" successText="permintaan info terkirim" />
            <RpcAction rpc="admin_ticket_resolve" args={{ p_ticket_id: ticket.id }}
              fields={[
                { name: "p_decision", label: "keputusan", type: "select", options: [
                  { value: "Refund penuh", label: "Refund penuh" },
                  { value: "Refund sebagian", label: "Refund sebagian" },
                  { value: "Peringatan ke bengkel", label: "Peringatan ke bengkel" },
                  { value: "Tidak ada pelanggaran", label: "Tidak ada pelanggaran" },
                  { value: "Masalah terselesaikan", label: "Masalah terselesaikan" },
                ] },
                { name: "p_reason", label: "alasan (tampil ke pelapor)", type: "textarea", required: true, minLength: 5 },
              ]}
              label="selesaikan tiket" tone="ok"
              confirmText="Tandai tiket selesai? Pelapor akan menerima keputusan ini." successText="tiket selesai" />
          </div>
        ) : (
          <div className="rounded-lg bg-panel p-5 text-sm text-ink/60 shadow-sm">tiket sudah selesai.</div>
        )}
        <div className="rounded-lg bg-panel p-5 shadow-sm">
          <h2 className="mb-2 text-sm font-semibold text-ink">Jejak audit</h2>
          <ul className="space-y-1 text-xs text-ink/60">
            {(audit ?? []).map((a) => (<li key={a.id}>{dateTime(a.created_at)} · {a.action}</li>))}
            {(audit ?? []).length === 0 && <li>belum ada aksi admin.</li>}
          </ul>
        </div>
      </aside>
    </div>
  );
}
