"use client";

import { useEffect, useRef, useState } from "react";
import { AppleSymbol, GooglePlaySymbol } from "./store-symbols";
import { ArrowRight, Check, Copy, FileText, Link2 } from "lucide-react";
import { toolCopy as c, type Tool } from "@/lib/free-tools-copy";
import { storeLinks } from "@/lib/links";

type Job = { id?: string; status?: string; transcript?: string; error?: string };
function track(event: string, slug: string, extra: Record<string, string> = {}) {
  // Deliberately excludes source URLs and transcripts.
  const w = window as Window & { dataLayer?: object[] };
  (w.dataLayer ||= []).push({ event, tool_slug: slug, ...extra });
}
function storeURL(platform: "appStore" | "googlePlay", slug: string) {
  const url = new URL(storeLinks[platform]);
  if (platform === "googlePlay") url.searchParams.set("referrer", new URLSearchParams({ utm_source: "website", utm_medium: "free_tool", utm_campaign: slug }).toString());
  else { url.searchParams.set("ct", `free_tool_${slug}`); url.searchParams.set("mt", "8"); }
  return url.toString();
}
export function ToolDownload({ slug, source }: { slug: string; source?: string }) {
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState(false);
  return <aside className="tool-download">
    <p className="home-kicker">{c.next}</p><h2>{c.ctaTitle}</h2><p>{c.ctaBody}</p>
    <div className="store-badges">
      <a className="store-badge store-badge-apple" aria-label={c.ios} href={storeURL("appStore", slug)} onClick={() => track("free_tool_download_clicked", slug, { platform: "ios" })}>
        <AppleSymbol /><span><small>{c.downloadLabel}</small><strong>{c.appStoreLabel}</strong></span><ArrowRight className="store-badge-arrow" size={16} aria-hidden />
      </a>
      <a className="store-badge store-badge-google" aria-label={c.android} href={storeURL("googlePlay", slug)} onClick={() => track("free_tool_download_clicked", slug, { platform: "android" })}>
        <GooglePlaySymbol /><span><small>{c.downloadLabel}</small><strong>{c.googlePlayLabel}</strong></span><ArrowRight className="store-badge-arrow" size={16} aria-hidden />
      </a>
    </div>
    <p className="tool-caption">{c.handoff}</p>
    {source && <button type="button" className="tool-text-button" onClick={async () => { try { await navigator.clipboard.writeText(source); setCopied(true); setError(false); } catch { setError(true); } }}>{copied ? c.copied : c.copySource}</button>}
    {error && <p role="status">{c.copyFailed}</p>}
  </aside>;
}

export function FreeTool({ tool }: { tool: Tool }) {
  const [url, setURL] = useState("");
  const [source, setSource] = useState("");
  const [job, setJob] = useState<Job>({});
  const [pending, setPending] = useState(false);
  const [error, setError] = useState("");
  const [copyStatus, setCopyStatus] = useState("");
  const controller = useRef<AbortController | null>(null);
  useEffect(() => { track("free_tool_viewed", tool.slug); return () => controller.current?.abort(); }, [tool.slug]);
  const errorText = (code: string) => c.errors[code as keyof typeof c.errors] || c.errors.unavailable;
  async function request(path: string, signal: AbortSignal, body?: object): Promise<Job> {
    const response = await fetch(`/api/free-tools/jobs${path}`, { method: body ? "POST" : "GET", headers: body ? { "Content-Type": "application/json" } : undefined, body: body ? JSON.stringify(body) : undefined, signal, cache: "no-store" });
    const data = await response.json() as Job;
    if (!response.ok) throw new Error(data.error || "unavailable");
    return data;
  }
  async function poll(id: string, signal: AbortSignal) {
    const deadline = Date.now() + 10 * 60_000;
    while (!signal.aborted) {
      const data = await request(`/${id}`, signal);
      setJob({ ...data, id });
      if (data.error) throw new Error(data.error);
      if (data.status === "ready") return;
      if (Date.now() > deadline) throw new Error("timeout");
      await new Promise<void>((resolve, reject) => {
        const done = () => { signal.removeEventListener("abort", abort); resolve(); };
        const timer = setTimeout(done, 2500);
        const abort = () => { clearTimeout(timer); reject(new DOMException("Aborted", "AbortError")); };
        signal.addEventListener("abort", abort, { once: true });
      });
    }
  }
  async function run() {
    controller.current?.abort();
    const ac = new AbortController(); controller.current = ac;
    setError(""); setCopyStatus(""); setPending(true);
    try {
        setJob({}); setSource("");
        track("free_tool_transcript_started", tool.slug);
        const data = await request("", ac.signal, { url: url.trim() });
        if (!data.id) throw new Error("unavailable");
        setSource(url.trim());
        await poll(data.id, ac.signal);
        track("free_tool_transcript_completed", tool.slug);
    } catch (err) {
      if (!ac.signal.aborted) {
        const code = err instanceof Error ? err.message : "unavailable";
        setError(errorText(code));
        track("free_tool_failed", tool.slug, { reason: code in c.errors ? code : "unavailable" });
      }
    } finally { if (!ac.signal.aborted) setPending(false); }
  }
  async function copy(text: string) {
    try { await navigator.clipboard.writeText(text); setCopyStatus(c.copied); track("free_tool_result_copied", tool.slug); }
    catch { setCopyStatus(c.copyFailed); }
  }
  return <>
    <section className="tool-workspace" aria-label={tool.name}>
      <form onSubmit={e => { e.preventDefault(); void run(); }} className="tool-form">
        <label htmlFor="video-url"><Link2 size={17} aria-hidden />{c.inputLabel}</label>
        <div className="tool-url-row"><input id="video-url" type="url" required maxLength={2048} value={url} onChange={e => setURL(e.target.value)} placeholder={c.placeholder} disabled={pending} autoComplete="off" />
          <button className="home-button primary" disabled={pending} type="submit">{c.submit}<ArrowRight size={17} aria-hidden /></button></div>
        <p className="tool-caption">{c.privacy} <a href="/privacy">{c.privacyLink}</a></p>
      </form>
      {pending && !job.transcript && <p className="tool-status" role="status"><span className="tool-pulse" aria-hidden />{c.processing}</p>}
      {error && <p className="tool-error" role="alert">{error}</p>}
      {!job.transcript ? <div className="tool-empty"><FileText size={30} aria-hidden /><h2>{c.emptyTitle}</h2><p>{c.emptyBody}</p></div> :
        <div className="tool-results">
          <div className="tool-result-heading"><h2>{c.transcript}</h2><button type="button" className="tool-text-button" onClick={() => copy(job.transcript!)}><Copy size={15} aria-hidden />{c.copy}</button></div>
          <div className="tool-output" tabIndex={0}>{job.transcript}</div>
          <p role="status" className="tool-caption">{copyStatus}</p><p className="tool-caption">{c.disclaimer}</p>
        </div>}
    </section>
    {job.transcript && <ToolDownload slug={tool.slug} source={source} />}
    <p className="tool-trust"><Check size={15} aria-hidden />{c.free}</p>
  </>;
}
