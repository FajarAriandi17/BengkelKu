// Label tampilan enum dari database (selaras dengan aplikasi mobile).
export const TICKET_CATEGORY: Record<string, string> = {
  BENGKEL_TIDAK_DATANG: "Bengkel tidak datang",
  HARGA_TIDAK_SESUAI: "Harga tidak sesuai",
  KERUSAKAN_SETELAH_SERVIS: "Kerusakan setelah servis",
  REFUND_BELUM_MASUK: "Refund belum masuk",
  PERILAKU_TIDAK_PANTAS: "Perilaku tidak pantas",
  LAINNYA: "Lainnya",
};

export const TICKET_STATE: Record<string, { label: string; cls: string }> = {
  DITERIMA: { label: "diterima", cls: "bg-blueSoft text-blue" },
  DITINJAU: { label: "ditinjau", cls: "bg-warnSoft text-warn" },
  MENUNGGU_INFO: { label: "menunggu info", cls: "bg-warnSoft text-warn" },
  SELESAI: { label: "selesai", cls: "bg-okSoft text-ok" },
};

export const CHAT_REPORT_STATE: Record<string, { label: string; cls: string }> = {
  open: { label: "baru", cls: "bg-badSoft text-bad" },
  reviewing: { label: "ditinjau", cls: "bg-warnSoft text-warn" },
  actioned: { label: "ditindak", cls: "bg-okSoft text-ok" },
  dismissed: { label: "diabaikan", cls: "bg-blueSoft text-blue" },
};

export const SOS_STATUS: Record<string, { label: string; cls: string }> = {
  MENUNGGU_PEMBAYARAN: { label: "menunggu bayar", cls: "bg-blueSoft text-blue" },
  MENCARI_BENGKEL: { label: "mencari bengkel", cls: "bg-warnSoft text-warn" },
  DITERIMA: { label: "diterima", cls: "bg-okSoft text-ok" },
  MENUJU_LOKASI: { label: "menuju lokasi", cls: "bg-okSoft text-ok" },
  TIBA: { label: "tiba", cls: "bg-okSoft text-ok" },
  MEMERIKSA: { label: "memeriksa", cls: "bg-okSoft text-ok" },
  DIKERJAKAN: { label: "dikerjakan", cls: "bg-okSoft text-ok" },
};

export const SOS_PROBLEM: Record<string, string> = {
  ENGINE_DEAD: "Mesin mati / mogok",
  FLAT_TIRE: "Ban bocor",
  DEAD_BATTERY: "Aki soak",
  OUT_OF_FUEL: "Kehabisan bensin",
  BRAKE_ISSUE: "Masalah rem",
  OTHER: "Lainnya",
};

export const BOOKING_STATUS: Record<string, { label: string; cls: string }> = {
  MENUNGGU_PEMBAYARAN: { label: "menunggu bayar", cls: "bg-blueSoft text-blue" },
  DIBAYAR_MENUNGGU_KONFIRMASI: { label: "menunggu konfirmasi", cls: "bg-warnSoft text-warn" },
  DIKONFIRMASI: { label: "dikonfirmasi", cls: "bg-okSoft text-ok" },
  CHECK_IN: { label: "check-in", cls: "bg-okSoft text-ok" },
  DIKERJAKAN: { label: "dikerjakan", cls: "bg-okSoft text-ok" },
  SELESAI: { label: "selesai", cls: "bg-okSoft text-ok" },
  PAYOUT: { label: "payout", cls: "bg-okSoft text-ok" },
  KEDALUWARSA: { label: "kedaluwarsa", cls: "bg-badSoft text-bad" },
  DITOLAK: { label: "ditolak", cls: "bg-badSoft text-bad" },
  DIBATALKAN: { label: "dibatalkan", cls: "bg-badSoft text-bad" },
  TIDAK_HADIR: { label: "tidak hadir", cls: "bg-badSoft text-bad" },
};
