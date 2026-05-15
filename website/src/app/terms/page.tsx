import type { Metadata } from "next";
import { MarketingShell } from "@/components/marketing-shell";

export const metadata: Metadata = {
  title: "Terms of Service | ChillNote",
  description: "Read the ChillNote user agreement and terms of service for the app, web app, and related services.",
};

export default function TermsPage() {
  return (
    <MarketingShell>
      <article className="legal-document">
        <p className="eyebrow">Legal</p>
        <h1>User Agreement</h1>
        <p><strong>Last Updated:</strong> January 2026</p>

        <p>
          Welcome to <strong>ChillNote</strong>. These Terms of Service govern your use of the ChillNote mobile app,
          web app, and related services provided by <strong>Sponteoai</strong>.
        </p>

        <h2>1. Use of the App</h2>
        <h3>License</h3>
        <p>
          Subject to your compliance with these terms, we grant you a limited, non-exclusive, non-transferable,
          revocable license to use ChillNote for your personal or internal creative workflow.
        </p>

        <h3>Restrictions</h3>
        <ul>
          <li>Do not use ChillNote for illegal purposes.</li>
          <li>Do not reverse engineer, decompile, or attempt to discover source code.</li>
          <li>Do not harass, abuse, or harm others.</li>
          <li>Do not interfere with or bypass security features.</li>
        </ul>

        <h2>2. User Content</h2>
        <p>
          You retain ownership of notes, recordings, links, transcripts, prompts, and other content you create or
          process with ChillNote. We do not claim ownership rights in your content.
        </p>
        <p>
          You are responsible for your content. When you import, paste, upload, or process third-party material, you
          represent that you have the rights, permissions, or lawful basis needed to store, summarize, transform, or
          otherwise use that material in ChillNote.
        </p>

        <h2>3. Privacy</h2>
        <p>
          Please review our <a className="inline-link" href="/privacy">Privacy Policy</a>, which explains how we collect,
          use, and protect information.
        </p>

        <h2>4. Updates and Changes</h2>
        <p>
          We may modify these terms from time to time. If a change is material, we will try to provide at least 30 days'
          notice before the new terms take effect.
        </p>

        <h2>5. Disclaimer of Warranties</h2>
        <p>
          ChillNote is provided on an "AS IS" and "AS AVAILABLE" basis. We do not guarantee uninterrupted availability or
          the accuracy of AI-generated transcription, summarization, or editing output.
        </p>

        <h2>6. Limitation of Liability</h2>
        <p>
          To the fullest extent permitted by law, Sponteoai shall not be liable for indirect, incidental, special,
          consequential, or punitive damages arising from your access to or use of ChillNote.
        </p>

        <h2>7. Contact</h2>
        <p>Questions about these terms? Contact us at <strong>support@chillnoteai.com</strong>.</p>
      </article>
    </MarketingShell>
  );
}
