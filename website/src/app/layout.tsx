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
  metadataBase: new URL("https://www.chillnoteai.com"),
  title: "ChillScript | Save inspiration. Create with AI.",
  description:
    "Save videos, extract ideas, capture thoughts, and turn your notes into content with AI creator skills.",
  openGraph: {
    type: "website",
    url: "/",
    title: "ChillScript | Save inspiration. Create with AI.",
    description:
      "Save videos, extract ideas, capture thoughts, and turn your notes into content with AI creator skills.",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "ChillScript creator workflow" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "ChillScript | Save inspiration. Create with AI.",
    description:
      "Save videos, extract ideas, capture thoughts, and turn your notes into content with AI creator skills.",
    images: ["/og.png"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={brandFont.variable}>
      <body>{children}</body>
    </html>
  );
}
