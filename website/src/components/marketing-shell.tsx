import { ArrowRight } from "lucide-react";
import Image from "next/image";
import { copy } from "@/lib/copy";
import { storeLinks } from "@/lib/links";
import { Wordmark } from "./wordmark";

export function MarketingHeader() {
  return (
    <header className="marketing-header">
      <div className="marketing-header-inner">
        <a className="brand-lockup" href="/">
          <Image src="/assets/chillscript-logo.png" alt="" width={40} height={40} />
          <Wordmark />
        </a>
        <nav aria-label="Main navigation">
          <a href="/#how-it-works">How it works</a>
          <a href="/pricing">{copy.nav.pricing}</a>
          <a className="nav-pill" href={storeLinks.appStore}>
            Get the app
            <ArrowRight aria-hidden size={14} />
          </a>
        </nav>
      </div>
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
        <p>Save inspiration. Extract ideas. Create with AI.</p>
      </div>
      <nav>
        <a href="/pricing">Pricing</a>
        <a href="/privacy">Privacy</a>
        <a href="/delete-account">Delete account</a>
        <a href="/terms">Terms</a>
        <a href={storeLinks.googlePlay}>
          Download ChillScript
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
