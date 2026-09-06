import { ArrowRight } from "lucide-react";
import { MarketingShell } from "@/components/marketing-shell";
import { ToolDownload } from "@/components/free-tool";
import { tools, toolCopy as c } from "@/lib/free-tools-copy";
import { toolMetadata } from "@/lib/free-tools-seo";
export const metadata = toolMetadata("Free Video Tools for Content Creators", c.hubDescription, "/tools");
export default function ToolsPage() {
  return <MarketingShell><div className="tools-page"><header className="tools-hero"><p className="home-kicker">{c.eyebrow}</p><h1>{c.hubTitle}</h1><p>{c.hubDescription}</p></header>
    <div className="tools-grid">{tools.map((tool, i) => <a key={tool.slug} href={`/${tool.slug}`} className="tool-card"><span className="tool-card-number">{String(i + 1).padStart(2, "0")}</span><h2>{tool.name}</h2><p>{tool.intro}</p><span>{c.open}<ArrowRight size={16} aria-hidden /></span></a>)}</div>
    <ToolDownload slug="tools" /></div></MarketingShell>;
}
