"use client";

import { useEffect, useState } from "react";
import {
  MessageSquareText,
  PenLine,
  Quote,
  Repeat2,
  Sparkles,
} from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";
import { copy } from "@/lib/copy";

const c = copy.landing.skills;

const tabs = [
  { key: "hooks", label: c.tabs.hooks, icon: Quote, rows: c.demos.hooks },
  { key: "caption", label: c.tabs.caption, icon: MessageSquareText, rows: c.demos.caption },
  { key: "humanizer", label: c.tabs.humanizer, icon: PenLine, rows: c.demos.humanizer },
  { key: "repurpose", label: c.tabs.repurpose, icon: Repeat2, rows: c.demos.repurpose },
] as const;

const AUTO_ADVANCE_MS = 2600;

export function SkillsSection() {
  const [active, setActive] = useState(0);
  const [auto, setAuto] = useState(true);

  useEffect(() => {
    if (!auto) return;
    const id = setInterval(() => {
      setActive((prev) => (prev + 1) % tabs.length);
    }, AUTO_ADVANCE_MS);
    return () => clearInterval(id);
  }, [auto]);

  const current = tabs[active];

  return (
    <section className="lp-section lp-skills">
      <div className="lp-section-inner lp-skills-inner">
        <motion.div
          className="lp-skills-head"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.5 }}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        >
          <span className="lp-eyebrow lp-eyebrow-icon">
            <Sparkles size={14} />
            {c.eyebrow}
          </span>
          <h2 className="lp-heading">
            {c.titlePrefix}
            <span className="lp-accent">{c.titleHighlight}</span>
          </h2>
          <p className="lp-lead">{c.body}</p>
        </motion.div>

        <motion.div
          className="lp-skills-demo"
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
        >
          <div className="lp-skills-tabs" role="tablist">
            {tabs.map((tab, i) => {
              const Icon = tab.icon;
              const isActive = i === active;
              return (
                <button
                  key={tab.key}
                  role="tab"
                  aria-selected={isActive}
                  className={`lp-skill-tab${isActive ? " is-active" : ""}`}
                  onClick={() => {
                    setAuto(false);
                    setActive(i);
                  }}
                >
                  <span className="lp-skill-tab-icon">
                    <Icon size={15} />
                  </span>
                  {tab.label}
                </button>
              );
            })}
          </div>

          <div className="lp-skill-output">
            <span className="lp-note-label">{c.previewLabel}</span>
            <AnimatePresence mode="wait">
              <motion.div
                key={current.key}
                className="lp-skill-rows"
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.32, ease: [0.16, 1, 0.3, 1] }}
              >
                {current.rows.map((row) => (
                  <div key={row.label} className="lp-skill-row">
                    <span className="lp-skill-pill">{row.label}</span>
                    <p>{row.text}</p>
                  </div>
                ))}
              </motion.div>
            </AnimatePresence>
          </div>

          <div className="lp-skill-build">
            <Sparkles size={15} />
            {c.buildYourOwn}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
