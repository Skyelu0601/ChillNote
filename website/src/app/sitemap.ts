import type { MetadataRoute } from "next";
import { tools } from "@/lib/free-tools-copy";
import { siteURL } from "@/lib/free-tools-seo";
export default function sitemap(): MetadataRoute.Sitemap {
  return ["", "/pricing", "/privacy", "/delete-account", "/terms", "/tools", ...tools.map(t => `/${t.slug}`)].map(path => ({ url: `${siteURL}${path}`, changeFrequency: "monthly", priority: path === "" ? 1 : path === "/tools" || tools.some(t => path === `/${t.slug}`) ? 0.8 : 0.4 }));
}
