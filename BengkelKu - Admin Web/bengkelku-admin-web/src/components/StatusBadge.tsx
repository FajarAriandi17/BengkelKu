// Badge status (bengkel/booking/payout) dengan warna token.
const MAP: Record<string, { label: string; cls: string }> = {
  // workshop
  pending: { label: "menunggu", cls: "bg-warnSoft text-warn" },
  verified: { label: "terverifikasi", cls: "bg-okSoft text-ok" },
  rejected: { label: "ditolak", cls: "bg-badSoft text-bad" },
  draft: { label: "draf", cls: "bg-blueSoft text-blue" },
  suspended: { label: "disuspensi", cls: "bg-badSoft text-bad" },
  // payout
  scheduled: { label: "dijadwalkan", cls: "bg-blueSoft text-blue" },
  processing: { label: "diproses", cls: "bg-warnSoft text-warn" },
  paid: { label: "dibayar", cls: "bg-okSoft text-ok" },
  failed: { label: "gagal", cls: "bg-badSoft text-bad" },
};

export function StatusBadge({ status }: { status: string }) {
  const s = MAP[status] ?? { label: status, cls: "bg-blueSoft text-blue" };
  return (
    <span
      className={`inline-flex rounded-pill px-2.5 py-0.5 text-xs font-semibold ${s.cls}`}
    >
      {s.label}
    </span>
  );
}
