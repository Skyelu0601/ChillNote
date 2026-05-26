import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ChillNote | AI Creator Notes",
  description:
    "ChillNote helps creators capture ideas, transcribe videos, break down hooks, descriptions, and transcripts, then reuse their AI creator notes with AI Skills.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
