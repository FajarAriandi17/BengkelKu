// Token desain admin — selaras dengan mobile (docs/DESIGN_SYSTEM.md).
// Dipakai untuk nilai di luar Tailwind (mis. style inline, chart).
export const tokens = {
  color: {
    panel: { light: "#FFFFFF", dark: "#121A30" },
    panel2: { light: "#F3F5FB", dark: "#0D1427" },
    ink: { light: "#0F172A", dark: "#E8ECF8" },
    blue: { light: "#1F4FD8", dark: "#3A66F2" },
    blueSoft: { light: "#E4EBFF", dark: "#18265A" },
    ok: "#15803D",
    okSoft: "#DCFCE7",
    warn: "#B45309",
    warnSoft: "#FEF3C7",
    bad: "#B91C1C",
    badSoft: "#FEE2E2",
    star: "#F59E0B",
    heart: "#E11D48",
  },
  radius: { sm: 12, md: 16, lg: 20, xl: 24, pill: 99 },
  motion: {
    easeOut: "cubic-bezier(0.22, 1, 0.36, 1)",
    spring: "cubic-bezier(0.34, 1.56, 0.64, 1)",
    micro: 180,
    screen: 300,
  },
} as const;

// Kode alasan baku penolakan verifikasi (dipakai di ReasonForm).
export const REJECT_REASONS = [
  { code: "DOC_BLUR", label: "Dokumen buram/tidak terbaca" },
  { code: "SELFIE_MISMATCH", label: "Wajah selfie tidak cocok dengan KTP" },
  { code: "NAME_MISMATCH", label: "Nama tidak cocok" },
  { code: "LOCATION_MISMATCH", label: "Lokasi foto tidak sesuai pin" },
  { code: "DUPLICATE", label: "Bengkel duplikat" },
  { code: "INCOMPLETE", label: "Data/dokumen tidak lengkap" },
  { code: "OTHER", label: "Lainnya (jelaskan)" },
] as const;
