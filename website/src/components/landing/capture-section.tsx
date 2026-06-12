"use client";

import { Image as ImageIcon, Link2, Mic, Music2 } from "lucide-react";
import { motion, type Variants } from "framer-motion";
import { copy } from "@/lib/copy";

const c = copy.landing.capture;

const chips = [
  { key: "link", label: c.chips.link, icon: Link2, active: true },
  { key: "voice", label: c.chips.voice, icon: Mic, active: false },
  { key: "photo", label: c.chips.photo, icon: ImageIcon, active: false },
  { key: "media", label: c.chips.media, icon: Music2, active: false },
];

const container: Variants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.12, delayChildren: 0.1 } },
};

const item: Variants = {
  hidden: { opacity: 0, y: 10 },
  show: { opacity: 1, y: 0, transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] } },
};

export function CaptureSection() {
  return (
    <section className="lp-section lp-capture">
      <div className="lp-section-inner lp-split">
        <motion.div
          className="lp-split-copy"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.4 }}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        >
          <span className="lp-eyebrow">{c.eyebrow}</span>
          <h2 className="lp-heading">
            {c.titlePrefix}
            <span className="lp-accent">{c.titleHighlight}</span>
            {c.titleSuffix}
          </h2>
          <p className="lp-lead">{c.body}</p>
          <div className="lp-chip-row">
            {chips.map((chip) => {
              const Icon = chip.icon;
              return (
                <span key={chip.key} className={`lp-chip${chip.active ? " is-active" : ""}`}>
                  <Icon size={14} />
                  {chip.label}
                </span>
              );
            })}
          </div>
        </motion.div>

        <motion.div
          className="lp-note-card"
          variants={container}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, amount: 0.3 }}
        >
          <motion.div className="lp-note-source" variants={item}>
            <span className="lp-note-source-badge">TT</span>
            <span className="lp-note-source-meta">
              <small>{c.card.sourcePlatform}</small>
              <strong>{c.card.sourceTitle}</strong>
            </span>
          </motion.div>

          <motion.h3 className="lp-note-title" variants={item}>
            {c.card.noteTitle}
          </motion.h3>

          <motion.div className="lp-note-field" variants={item}>
            <span className="lp-note-label">{c.card.descriptionLabel}</span>
            <p>{c.card.description}</p>
          </motion.div>

          <motion.div className="lp-note-field" variants={item}>
            <span className="lp-note-label">{c.card.authorLabel}</span>
            <div className="lp-note-author">
              <span className="lp-note-avatar">CM</span>
              {c.card.author}
            </div>
          </motion.div>

          <motion.div className="lp-note-field" variants={item}>
            <span className="lp-note-label">{c.card.hookLabel}</span>
            <p className="lp-note-hook">{c.card.hook}</p>
          </motion.div>

          <motion.div className="lp-note-field lp-note-transcript" variants={item}>
            <span className="lp-note-label">{c.card.transcriptLabel}</span>
            <p>{c.card.transcript}</p>
            <span className="lp-note-fade" aria-hidden />
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
