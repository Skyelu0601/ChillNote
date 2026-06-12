import type { Metadata } from "next";
import { Mulish } from "next/font/google";
import "./globals.css";

const brandFont = Mulish({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800", "900"],
  style: ["normal", "italic"],
  variable: "--font-brand",
  display: "swap",
});

export const metadata: Metadata = {
  title: "ChillNote | AI Creator Notes",
  description:
    "ChillNote helps creators capture ideas, transcribe videos, break down hooks, descriptions, and transcripts, then reuse their AI creator notes with AI Skills.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={brandFont.variable}>
      <body>{children}</body>
    </html>
  );
}
