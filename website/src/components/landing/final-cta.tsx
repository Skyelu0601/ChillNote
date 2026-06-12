"use client";

import { ArrowRight } from "lucide-react";
import { motion } from "framer-motion";
import { copy } from "@/lib/copy";

const c = copy.landing.final;

export function FinalCta() {
  return (
    <section className="lp-section lp-final">
      <motion.div
        className="lp-final-card"
        initial={{ opacity: 0, y: 28 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.4 }}
        transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
      >
        <span className="lp-final-glow" aria-hidden />
        <h2>
          {c.titlePrefix}
          <span className="lp-grad-text">{c.titleHighlight}</span>
          {c.titleSuffix}
        </h2>
        <p>{c.body}</p>
        <div className="lp-hero-actions lp-final-actions">
          <a
            className="lp-btn lp-btn-primary"
            href="https://apps.apple.com/us/app/chillnote-ai-quick-capture/id6758427839"
          >
            {c.primaryAction}
            <ArrowRight size={18} />
          </a>
          <a className="lp-btn lp-btn-ghost lp-btn-on-dark" href="/app">
            {c.secondaryAction}
          </a>
        </div>
      </motion.div>
    </section>
  );
}
