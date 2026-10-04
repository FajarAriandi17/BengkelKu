import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "BengkelKu Admin",
  description: "Panel admin internal BengkelKu — verifikasi bengkel.",
  robots: { index: false, follow: false },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
