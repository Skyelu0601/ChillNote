"use client";

import { ArrowRight } from "lucide-react";
import { motion } from "framer-motion";
import { copy } from "@/lib/copy";
import { Wordmark } from "../wordmark";
import { Orbit } from "./orbit";

const c = copy.landing.hero;

export function Hero() {
  return (
    <section className="lp-hero">
      <div className="lp-hero-glow" aria-hidden />
      <div className="lp-hero-inner">
        <motion.div
          className="lp-hero-copy"
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
        >
          <Wordmark className="lp-hero-wordmark" />
          <h1>
            <span>{c.headlineTop}</span>
            <span className="lp-grad-text">{c.headlineBottom}</span>
          </h1>
          <p>{c.subtitle}</p>
          <div className="lp-hero-actions">
            <a className="lp-btn lp-btn-primary" href="https://apps.apple.com/us/app/chillnote-ai-quick-capture/id6758427839">
              {c.primaryAction}
              <ArrowRight size={18} />
            </a>
            <a className="lp-btn lp-btn-ghost" href="/app">
              {c.secondaryAction}
            </a>
          </div>
        </motion.div>

        <motion.div
          className="lp-hero-orbit-wrap"
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, delay: 0.15, ease: [0.16, 1, 0.3, 1] }}
        >
          <Orbit />
          <p className="lp-orbit-caption">{c.orbitCaption}</p>
        </motion.div>
      </div>
    </section>
  );
}
