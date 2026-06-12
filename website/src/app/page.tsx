import { MarketingShell } from "@/components/marketing-shell";
import { Hero } from "@/components/landing/hero";
import { CaptureSection } from "@/components/landing/capture-section";
import { ShareSection } from "@/components/landing/share-section";
import { SkillsSection } from "@/components/landing/skills-section";
import { FinalCta } from "@/components/landing/final-cta";

export default function LandingPage() {
  return (
    <MarketingShell>
      <Hero />
      <CaptureSection />
      <ShareSection />
      <SkillsSection />
      <FinalCta />
    </MarketingShell>
  );
}
