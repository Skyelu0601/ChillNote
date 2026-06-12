"use client";

import { CheckCircle2, Lightbulb, Mic } from "lucide-react";
import { motion } from "framer-motion";
import { BoltMark, ReelsGlyph, TikTokGlyph, YouTubeGlyph } from "./glyphs";

type OrbitIcon = {
  id: string;
  node: React.ReactNode;
  tint: string;
};

// Clockwise from 12 o'clock, mirroring the iOS onboarding ring.
const orbitIcons: OrbitIcon[] = [
  { id: "idea", node: <Lightbulb size={22} />, tint: "#f5bb2b" },
  { id: "reels", node: <ReelsGlyph size={24} />, tint: "transparent" },
  { id: "youtube", node: <YouTubeGlyph size={24} />, tint: "transparent" },
  { id: "todo", node: <CheckCircle2 size={22} />, tint: "#33b85e" },
  { id: "mic", node: <Mic size={21} />, tint: "#876bf7" },
  { id: "tiktok", node: <TikTokGlyph size={24} />, tint: "transparent" },
];

const RADIUS = 150;
const ORBIT_DURATION = 38;

export function Orbit({ boltSize = 112 }: { boltSize?: number }) {
  return (
    <div className="lp-orbit" aria-hidden>
      {/* concentric guide rings */}
      <span className="lp-orbit-ring lp-orbit-ring-1" />
      <span className="lp-orbit-ring lp-orbit-ring-2" />

      {/* breathing halo + pulsing wave behind the bolt */}
      <motion.span
        className="lp-orbit-halo"
        animate={{ scale: [1, 1.12, 1], opacity: [0.5, 0.75, 0.5] }}
        transition={{ duration: 3.4, repeat: Infinity, ease: "easeInOut" }}
      />
      <motion.span
        className="lp-orbit-pulse"
        animate={{ scale: [1, 1.6], opacity: [0.45, 0] }}
        transition={{ duration: 3, repeat: Infinity, ease: "easeOut" }}
      />

      {/* center bolt */}
      <motion.div
        className="lp-orbit-bolt"
        animate={{ scale: [1, 1.05, 1] }}
        transition={{ duration: 3.4, repeat: Infinity, ease: "easeInOut" }}
      >
        <BoltMark size={boltSize} />
      </motion.div>

      {/* rotating icon layer */}
      <motion.div
        className="lp-orbit-layer"
        animate={{ rotate: 360 }}
        transition={{ duration: ORBIT_DURATION, repeat: Infinity, ease: "linear" }}
      >
        {orbitIcons.map((icon, index) => {
          const theta = -Math.PI / 2 + index * (Math.PI / 3);
          const x = RADIUS * Math.cos(theta);
          const y = RADIUS * Math.sin(theta);
          return (
            <div
              key={icon.id}
              className="lp-orbit-slot"
              style={{ transform: `translate(-50%, -50%) translate(${x}px, ${y}px)` }}
            >
              {/* counter-rotate so glyphs stay upright + gentle staggered float */}
              <motion.div
                className="lp-orbit-card"
                style={{ color: icon.tint }}
                animate={{ rotate: -360, y: [0, -6, 0] }}
                transition={{
                  rotate: { duration: ORBIT_DURATION, repeat: Infinity, ease: "linear" },
                  y: { duration: 3.2, repeat: Infinity, ease: "easeInOut", delay: index * 0.4 },
                }}
              >
                {icon.node}
              </motion.div>
            </div>
          );
        })}
      </motion.div>
    </div>
  );
}
