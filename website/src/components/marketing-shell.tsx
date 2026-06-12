import { ArrowRight } from "lucide-react";
import { copy } from "@/lib/copy";
import { Wordmark } from "./wordmark";

export function MarketingHeader() {
  return (
    <header className="marketing-header">
      <a className="brand-lockup" href="/">
        <img src="/assets/chillnote-logo.png" alt="" />
        <Wordmark />
      </a>
      <nav>
        <a href="/pricing">{copy.nav.pricing}</a>
        <a href="/privacy">{copy.nav.privacy}</a>
        <a href="/terms">{copy.nav.terms}</a>
        <a href="https://apps.apple.com/us/app/chillnote-ai-quick-capture/id6758427839">
          {copy.nav.appStore}
        </a>
        <a className="nav-pill" href="/app">
          {copy.nav.app}
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
          <img src="/assets/chillnote-logo.png" alt="" />
          <span>{copy.productName}</span>
        </a>
        <p>AI creator notes, quick capture, and reusable workflows.</p>
      </div>
      <nav>
        <a href="/pricing">Pricing</a>
        <a href="/privacy">Privacy</a>
        <a href="/terms">Terms</a>
        <a href="/app">
          Sign in
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
