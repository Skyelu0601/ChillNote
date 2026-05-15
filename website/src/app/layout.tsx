import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ChillNote | Creator Swipe Files and AI Content Notes",
  description:
    "ChillNote helps creators capture ideas, transcribe videos, break down hooks, descriptions, and transcripts, then reuse swipe files with AI Skills.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
