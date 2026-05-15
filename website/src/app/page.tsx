import {
  ArrowRight,
  FileText,
  Lightbulb,
  PlaySquare,
  Repeat2,
  Scissors,
  Sparkles,
} from "lucide-react";
import { copy } from "@/lib/copy";
import { MarketingShell } from "@/components/marketing-shell";

const features = [
  {
    icon: PlaySquare,
    title: "Video to text",
    body: "Save creator videos and turn the source material into clean transcripts you can search, quote, and remix.",
  },
  {
    icon: Scissors,
    title: "Hook breakdowns",
    body: "Pull apart the hook, description, structure, and transcript so you can see why a piece of content works.",
  },
  {
    icon: Lightbulb,
    title: "Quick Capture Ideas",
    body: "Grab rough post angles the moment they appear, then attach source links, tags, and creator context later.",
  },
  {
    icon: Repeat2,
    title: "Reusable AI Skills",
    body: "Run saved creative workflows against your swipe files to draft new posts from patterns you already trust.",
  },
];

const workflow = [
  "Capture a video, link, quote, or messy idea.",
  "Transcribe and split the material into hook, description, and transcript.",
  "Save the pattern as a swipe file and reuse it with AI Skills.",
];

export default function LandingPage() {
  return (
    <MarketingShell>
      <section className="hero-band">
        <div className="hero-copy">
          <p className="eyebrow">{copy.landing.eyebrow}</p>
          <h1>{copy.landing.title}</h1>
          <p>{copy.landing.subtitle}</p>
          <div className="hero-actions">
            <a className="primary-button" href="/app">
              {copy.landing.primaryAction}
              <ArrowRight size={18} />
            </a>
            <a className="secondary-button" href="/app">
              {copy.landing.secondaryAction}
            </a>
          </div>
          <div className="hero-tags" aria-label="Core creator workflows">
            <span>Video transcript</span>
            <span>Hook analysis</span>
            <span>Swipe file</span>
            <span>AI Skills</span>
          </div>
        </div>
        <div className="product-shot" aria-label={copy.landing.status}>
          <div className="creator-preview">
            <div className="preview-toolbar">
              <span>Creator Swipe File</span>
              <strong>TikTok launch teardown</strong>
            </div>
            <div className="preview-grid">
              <div className="video-panel">
                <PlaySquare size={34} />
                <span>Video saved</span>
                <strong>0:47 transcript ready</strong>
              </div>
              <div className="analysis-panel">
                <div>
                  <span>Hook</span>
                  <p>Start with the painful before state, then promise the faster workflow.</p>
                </div>
                <div>
                  <span>Description</span>
                  <p>Short proof, clear outcome, one direct call to action.</p>
                </div>
                <div>
                  <span>Transcript</span>
                  <p>Segmented into claim, demo, result, and reusable phrasing.</p>
                </div>
              </div>
              <div className="skill-panel">
                <Sparkles size={20} />
                <strong>AI Skill</strong>
                <p>Generate 5 new hooks from this swipe file.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="feature-band">
        <div className="section-heading">
          <p className="eyebrow">{copy.landing.status}</p>
          <h2>{copy.landing.featureTitle}</h2>
          <p>{copy.landing.featureBody}</p>
        </div>
        <div className="feature-grid">
          {features.map((feature) => {
            const Icon = feature.icon;
            return (
              <article className="feature-card" key={feature.title}>
                <Icon size={22} />
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
              </article>
            );
          })}
        </div>
      </section>

      <section className="workflow-band">
        <div className="section-heading">
          <p className="eyebrow">Built for content loops</p>
          <h2>From inspiration to your next draft.</h2>
        </div>
        <div className="workflow-list" aria-label="ChillNote creator workflow">
          {workflow.map((item, index) => (
            <article className="workflow-step" key={item}>
              <span>{index + 1}</span>
              <p>{item}</p>
            </article>
          ))}
        </div>
        <div className="final-cta">
          <FileText size={22} />
          <div>
            <strong>Start a creator swipe file in the web app.</strong>
            <p>Use ChillNote on desktop for deeper breakdowns, and iOS for quick capture when ideas show up between tasks.</p>
          </div>
          <a className="primary-button compact" href="/app">
            Enter Web App
            <ArrowRight size={17} />
          </a>
        </div>
      </section>
    </MarketingShell>
  );
}
