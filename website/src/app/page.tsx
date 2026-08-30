import type { Metadata } from "next";
import {
  ArrowRight,
  Check,
  FileText,
  Link2,
  Mic,
  Play,
  Sparkles,
  WandSparkles,
} from "lucide-react";
import { MarketingShell } from "@/components/marketing-shell";
import { storeLinks } from "@/lib/links";

export const metadata: Metadata = {
  title: "ChillScript | Save inspiration. Create with AI.",
  description:
    "Save videos, extract ideas, capture thoughts, and turn your notes into content with AI creator skills.",
};

const platforms = ["TikTok", "YouTube", "Instagram Reels"];
const extractedFields = [
  ["Description", "A clear summary of what made the video worth saving."],
  ["Author", "The original creator and source context."],
  ["Link", "A direct path back to the original video."],
  ["Transcript", "The full spoken content, ready to search and reuse."],
];
const creatorSkills = [
  ["Hook Generator", "Installed", "blue"],
  ["Rewrite", "Installed", "teal"],
  ["Caption Pack", "Installed", "honey"],
  ["Repurpose Pack", "Installed", "violet"],
  ["Humanizer", "New", "rose"],
];

function StoreButtons({ compact = false }: { compact?: boolean }) {
  return (
    <div className={compact ? "home-actions compact" : "home-actions"}>
      <a className="home-button primary" href={storeLinks.appStore}>
        Get the iOS App <ArrowRight aria-hidden size={17} />
      </a>
      <a className="home-button secondary" href={storeLinks.googlePlay}>
        Get the Android App <ArrowRight aria-hidden size={17} />
      </a>
    </div>
  );
}

function PhoneDemo({ video, poster, label }: { video: string; poster: string; label: string }) {
  return (
    <div className="phone-demo" aria-label={label}>
      <div className="phone-speaker" aria-hidden />
      <video autoPlay loop muted playsInline preload="metadata" poster={poster}>
        <source src={video} type="video/mp4" />
      </video>
    </div>
  );
}

export default function LandingPage() {
  return (
    <MarketingShell>
      <section className="home-hero">
        <div className="hero-orb orb-blue" aria-hidden />
        <div className="hero-orb orb-teal" aria-hidden />
        <div className="home-hero-copy">
          <p className="home-kicker"><Sparkles aria-hidden size={16} /> Built for creators</p>
          <h1>Save videos. Extract ideas. <span>Create with AI.</span></h1>
          <p className="home-hero-lead">
            ChillScript turns the inspiration you find and the thoughts you capture into clear,
            reusable creator notes—ready for your next script, caption, or post.
          </p>
          <StoreButtons />
          <p className="home-trust"><Check aria-hidden size={15} /> Start free · Available on iPhone and Android</p>
        </div>
        <div className="hero-demo-wrap">
          <div className="hero-demo-card">
            <PhoneDemo video="/assets/onboarding-demo-1.mp4" poster="/assets/onboarding-demo-1.jpg" label="ChillScript app demonstration" />
          </div>
          <div className="floating-note floating-note-top"><Play aria-hidden size={16} fill="currentColor" /><span>Video saved</span></div>
          <div className="floating-note floating-note-bottom"><WandSparkles aria-hidden size={17} /><span>Ideas extracted</span></div>
        </div>
      </section>

      <section className="journey-intro" id="how-it-works">
        <p className="home-kicker">One creative flow</p>
        <h2>From “save this” to “publish this.”</h2>
        <p>ChillScript keeps inspiration moving instead of letting it disappear into a camera roll or a pile of tabs.</p>
      </section>

      <section className="story-section">
        <div className="story-copy">
          <span className="story-number">01</span>
          <p className="home-kicker">Save from anywhere</p>
          <h2>Save your first <span>video.</span></h2>
          <p>Share a video straight to ChillScript while you browse. No copying into a blank document, no losing the source, and no breaking your creative rhythm.</p>
          <div className="platform-row">{platforms.map((platform) => <span key={platform}>{platform}</span>)}</div>
        </div>
        <div className="story-visual soft-blue">
          <PhoneDemo video="/assets/onboarding-demo-1.mp4" poster="/assets/onboarding-demo-1.jpg" label="Saving a video to ChillScript" />
        </div>
      </section>

      <section className="story-section reverse">
        <div className="story-copy">
          <span className="story-number">02</span>
          <p className="home-kicker">Automatic organization</p>
          <h2>See the useful ideas, <span>already extracted.</span></h2>
          <p>Open ChillScript and your saved video becomes a structured note. The context you need is kept together, searchable, and ready to reuse.</p>
          <div className="extracted-list">
            {extractedFields.map(([title, body]) => (
              <div key={title}><Check aria-hidden size={16} /><span><strong>{title}</strong>{body}</span></div>
            ))}
          </div>
        </div>
        <div className="story-visual soft-teal">
          <PhoneDemo video="/assets/onboarding-demo-2.mp4" poster="/assets/onboarding-demo-2.jpg" label="ChillScript extracting ideas from a saved video" />
        </div>
      </section>

      <section className="capture-panel">
        <div className="capture-heading">
          <span className="story-number">03</span>
          <p className="home-kicker">Capture your way</p>
          <h2>Never lose a great <span>idea.</span></h2>
          <p>Not every idea starts with a video. Type it, say it, or paste the link before the moment passes.</p>
        </div>
        <div className="capture-grid">
          <article>
            <div className="capture-icon blue"><FileText aria-hidden /></div><h3>Text</h3><p>Write freely, without templates or limits.</p>
            <div className="mini-note"><strong>Video idea</strong><span>Your best ideas do not wait for a blank doc.</span></div>
          </article>
          <article>
            <div className="capture-icon teal"><Mic aria-hidden /></div><h3>Voice</h3><p>Speak naturally. ChillScript turns the messy thought into a clear note.</p>
            <div className="voice-wave" aria-hidden><i /><i /><i /><i /><i /><i /><i /></div>
          </article>
          <article>
            <div className="capture-icon honey"><Link2 aria-hidden /></div><h3>Links</h3><p>Paste videos, articles, or anywhere inspiration starts.</p>
            <div className="link-preview"><span>chillscript</span><strong>Idea saved with its source</strong></div>
          </article>
        </div>
      </section>

      <section className="story-section hooks-section">
        <div className="story-copy">
          <span className="story-number">04</span>
          <p className="home-kicker">Create from what you saved</p>
          <h2>Generate <span>hooks</span> from your notes.</h2>
          <p>Pick the notes that matter and let ChillScript turn the ideas inside them into strong openings you can shape into your own content.</p>
          <div className="hook-quote"><Sparkles aria-hidden size={18} /><p>“What if your next post is already sitting in your notes?”</p></div>
        </div>
        <div className="story-visual soft-honey">
          <PhoneDemo video="/assets/onboarding-demo-3.mp4" poster="/assets/onboarding-demo-3.jpg" label="Generating hooks from notes in ChillScript" />
        </div>
      </section>

      <section className="skills-panel">
        <div className="skills-copy">
          <span className="story-number">05</span>
          <p className="home-kicker">AI skills for creators</p>
          <h2>Hooks are just the <span>start.</span></h2>
          <p>Run focused AI Skills on your notes to rewrite an idea, build a caption pack, repurpose a draft, or make the result sound more like you.</p>
          <div className="skills-summary"><WandSparkles aria-hidden size={18} /> 10+ creator skills and your own custom workflows</div>
        </div>
        <div className="skills-library">
          <div className="library-title"><span>Skill library</span><span>10+</span></div>
          {creatorSkills.map(([name, status, color]) => (
            <div className="skill-row" key={name}><span className={`skill-icon ${color}`}><Sparkles aria-hidden size={17} /></span><strong>{name}</strong><em className={status === "New" ? "new" : ""}>{status}</em></div>
          ))}
          <div className="build-skill"><span>+</span><strong>Build your own</strong><em>Pro</em></div>
        </div>
      </section>

      <section className="home-final">
        <div>
          <p className="home-kicker">Your next idea is already waiting</p>
          <h2>Save it now. <span>Create with it later.</span></h2>
          <p>Bring videos, voice notes, links, and half-formed thoughts into one calm creative workspace.</p>
          <StoreButtons compact />
        </div>
      </section>
    </MarketingShell>
  );
}
