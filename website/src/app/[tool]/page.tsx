import { notFound } from "next/navigation";
import { ArrowRight } from "lucide-react";
import { MarketingShell } from "@/components/marketing-shell";
import { FreeTool, ToolDownload } from "@/components/free-tool";
import { tools, toolCopy as c } from "@/lib/free-tools-copy";
import { siteURL, toolMetadata } from "@/lib/free-tools-seo";

export const dynamicParams = false;
export function generateStaticParams() { return tools.map(t => ({ tool: t.slug })); }
type Props = { params: Promise<{ tool: string }> };
export async function generateMetadata({ params }: Props) {
  const slug = (await params).tool;
  const entry = tools.find(t => t.slug === slug);
  if (!entry) return {};
  return toolMetadata(entry.title, entry.description, `/${entry.slug}`);
}
export default async function ToolPage({ params }: Props) {
  const slug = (await params).tool;
  const tool = tools.find(t => t.slug === slug);
  if (!tool) notFound();
  const faqs = [...tool.faqs, ...c.commonFaqs];
  const schema = { "@context": "https://schema.org", "@graph": [
    { "@type": "WebApplication", name: tool.appFeature ? c.transcript : tool.name, url: `${siteURL}/${tool.slug}`, description: tool.description, applicationCategory: "MultimediaApplication", operatingSystem: "Any", isAccessibleForFree: true, offers: { "@type": "Offer", price: "0", priceCurrency: "USD" } },
    { "@type": "BreadcrumbList", itemListElement: [{ "@type": "ListItem", position: 1, name: c.nav, item: `${siteURL}/tools` }, { "@type": "ListItem", position: 2, name: tool.name, item: `${siteURL}/${tool.slug}` }] }
  ] };
  return <MarketingShell><div className="tools-page">
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema).replace(/</g, "\\u003c") }} />
    <a href="/tools" className="tool-back">← {c.back}</a>
    <header className="tools-hero"><p className="home-kicker">{c.eyebrow}</p><h1>{tool.title}</h1><p>{tool.intro}</p><span className="tool-platform">{tool.platform}</span>{tool.appFeature && <p className="tool-caption">{c.appFeatureNotice}</p>}</header>
    <FreeTool tool={tool} />
    <section className="tool-guide"><div><p className="home-kicker">{c.how}</p><ol>{tool.steps.map(step => <li key={step}>{step}</li>)}</ol></div><div><h2>{c.why}</h2><p>{tool.use}</p></div></section>
    <section className="tool-faq"><h2>{c.faq}</h2>{faqs.map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}</section>
    <ToolDownload slug={tool.slug} />
    <section className="tools-related"><h2>{c.related}</h2><div className="tools-grid">{tools.filter(t => t.slug !== slug).map(t => <a className="tool-card" key={t.slug} href={`/${t.slug}`}><h3>{t.name}</h3><p>{t.intro}</p><span>{c.open}<ArrowRight size={16} aria-hidden /></span></a>)}</div></section>
  </div></MarketingShell>;
}
