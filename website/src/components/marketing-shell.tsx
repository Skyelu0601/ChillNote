import { ArrowRight } from "lucide-react";
import Image from "next/image";
import { copy } from "@/lib/copy";
import { storeLinks } from "@/lib/links";
import { Wordmark } from "./wordmark";

export function MarketingHeader() {
  return (
    <header className="marketing-header">
      <a className="brand-lockup" href="/">
        <Image src="/assets/chillscript-logo.png" alt="" width={40} height={40} />
        <Wordmark />
      </a>
      <nav>
        <a href="/pricing">{copy.nav.pricing}</a>
        <a href="/privacy">{copy.nav.privacy}</a>
        <a href="/terms">{copy.nav.terms}</a>
        <a href={storeLinks.appStore}>
          {copy.nav.appStore}
        </a>
        <a className="nav-pill" href={storeLinks.googlePlay}>
          {copy.nav.googlePlay}
        </a>
      </nav>
    </header>
  );
}

export function MarketingFooter() {
  return (
    <footer className="marketing-footer">
      <div>
        <a className="brand-lockup" href="/">
          <Image src="/assets/chillscript-logo.png" alt="" width={40} height={40} />
          <span>{copy.productName}</span>
        </a>
        <p>AI creator notes, quick capture, and reusable workflows.</p>
      </div>
      <nav>
        <a href="/pricing">Pricing</a>
        <a href="/privacy">Privacy</a>
        <a href="/delete-account">Delete account</a>
        <a href="/terms">Terms</a>
        <a href={storeLinks.googlePlay}>
          Get the Android app
          <ArrowRight size={16} />
        </a>
      </nav>
    </footer>
  );
}

export function MarketingShell({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <main className="site-shell">
      <MarketingHeader />
      {children}
      <MarketingFooter />
    </main>
  );
}
