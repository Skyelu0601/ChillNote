"use client";

import { Share } from "lucide-react";
import { motion } from "framer-motion";
import { copy } from "@/lib/copy";

const c = copy.landing.share;

export function ShareSection() {
  return (
    <section className="lp-section lp-share">
      <div className="lp-section-inner lp-split lp-split-reverse">
        <motion.div
          className="lp-phone"
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
        >
          <div className="lp-phone-frame">
            <video
              className="lp-phone-video"
              autoPlay
              muted
              loop
              playsInline
              poster="/assets/share-demo-poster.jpg"
            >
              <source src="/assets/share-demo.webm" type="video/webm" />
              <source src="/assets/share-demo.mp4" type="video/mp4" />
            </video>
          </div>
        </motion.div>

        <motion.div
          className="lp-split-copy"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.4 }}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        >
          <span className="lp-eyebrow lp-eyebrow-icon">
            <Share size={14} />
            {c.eyebrow}
          </span>
          <h2 className="lp-heading">
            {c.titlePrefix}
            <span className="lp-accent">{c.titleHighlight}</span>
            {c.titleSuffix}
          </h2>
          <p className="lp-lead">{c.body}</p>
          <ol className="lp-steps">
            {c.steps.map((step, i) => (
              <motion.li
                key={step}
                initial={{ opacity: 0, x: -10 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, amount: 0.6 }}
                transition={{ duration: 0.45, delay: 0.15 + i * 0.12, ease: [0.16, 1, 0.3, 1] }}
              >
                <span className="lp-step-num">{i + 1}</span>
                {step}
              </motion.li>
            ))}
          </ol>
        </motion.div>
      </div>
    </section>
  );
}
