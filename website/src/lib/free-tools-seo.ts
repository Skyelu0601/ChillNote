import type { Metadata } from "next";
export const siteURL = "https://www.chillnoteai.com";
export function toolMetadata(title: string, description: string, path: string): Metadata {
  return { title: `${title} | ChillScript`, description, alternates: { canonical: path },
    openGraph: { title: `${title} | ChillScript`, description, url: path, type: "website", images: [{ url: "/og.png", width: 1200, height: 630, alt: title }] },
    twitter: { card: "summary_large_image", title: `${title} | ChillScript`, description, images: ["/og.png"] }
  };
}
