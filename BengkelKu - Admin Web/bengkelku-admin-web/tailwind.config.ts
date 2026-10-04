import type { Config } from "tailwindcss";

// Token selaras dengan mobile (lihat src/lib/theme/tokens.ts & ../bengkelku-mobile/docs/DESIGN_SYSTEM.md)
const config: Config = {
  darkMode: "class",
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        panel: { DEFAULT: "#FFFFFF", dark: "#121A30" },
        panel2: { DEFAULT: "#F3F5FB", dark: "#0D1427" },
        ink: { DEFAULT: "#0F172A", dark: "#E8ECF8" },
        blue: { DEFAULT: "#1F4FD8", dark: "#3A66F2" },
        blueSoft: { DEFAULT: "#E4EBFF", dark: "#18265A" },
        ok: "#15803D",
        okSoft: "#DCFCE7",
        warn: "#B45309",
        warnSoft: "#FEF3C7",
        bad: "#B91C1C",
        badSoft: "#FEE2E2",
        star: "#F59E0B",
        heart: "#E11D48",
      },
      borderRadius: {
        sm: "12px",
        md: "16px",
        lg: "20px",
        xl: "24px",
        pill: "99px",
      },
      fontFamily: {
        sans: ["Plus Jakarta Sans", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
};

export default config;
