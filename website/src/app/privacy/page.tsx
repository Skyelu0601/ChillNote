import type { Metadata } from "next";
import { MarketingShell } from "@/components/marketing-shell";

export const metadata: Metadata = {
  title: "Privacy Policy | ChillNote",
  description:
    "Read how ChillNote handles account data, notes, audio processing, AI requests, retention, and security.",
};

export default function PrivacyPage() {
  return (
    <MarketingShell>
      <article className="legal-document">
        <p className="eyebrow">Legal</p>
        <h1>Privacy Policy</h1>
        <p><strong>Last Updated:</strong> March 20, 2026</p>

        <p>
          <strong>Sponteoai</strong> respects your privacy and is committed to protecting it. This policy describes the
          information we may collect when you use <strong>ChillNote</strong>, including the mobile app, web app, and
          related services.
        </p>

        <h2>1. Information We Collect</h2>
        <h3>Account Information</h3>
        <p>When you sign in, we collect the account identifiers and email address needed to authenticate you and sync your data.</p>

        <h3>Notes and Text Content</h3>
        <p>
          Notes you save are stored securely so they can sync across devices. Text you intentionally submit to AI may be
          sent only for that requested action, such as tidying, rewriting, summarizing, translating, or running an AI Skill.
        </p>

        <h3>Audio Data</h3>
        <p>
          We process audio only when you actively record or transcribe. Raw audio is handled transiently for the active
          request and is not retained on our servers after processing is complete.
        </p>

        <h3>Device and Diagnostic Data</h3>
        <p>
          We may collect generic device and compatibility information. Limited diagnostic events may be stored locally
          for debugging. We do not sell personal data or upload detailed behavioral tracking data to third-party
          advertising platforms.
        </p>

        <h2>2. How We Use Information</h2>
        <ul>
          <li>Authenticate your account and keep you signed in.</li>
          <li>Sync notes and topics across devices.</li>
          <li>Process AI features you intentionally request.</li>
          <li>Maintain performance, security, and compatibility.</li>
        </ul>
        <p><strong>No Model Training:</strong> We and our third-party partners do not use your notes or recordings to train models.</p>

        <h2>3. AI Processing Disclosure</h2>
        <p>
          AI processing happens only when you intentionally use an AI feature. Voice transcription may send audio and
          technical parameters. Text AI features may send selected note text, prompt text, source text, or link-derived
          text needed to complete the specific request.
        </p>

        <h2>4. Third-Party Processors</h2>
        <p>
          ChillNote may send the minimum data needed for an active request to secure AI processors, including Google
          Gemini via Google Cloud, for transcription, summarization, note improvement, translation, and related AI tasks.
        </p>

        <h2>5. Data Retention and Security</h2>
        <ul>
          <li>Raw audio is processed transiently and is not retained on server disk after processing.</li>
          <li>Local temporary recordings may remain on your device for crash recovery or pending transcription and are deleted after successful processing or within 7 days.</li>
          <li>Text notes remain stored until you delete them or delete your account.</li>
          <li>Data is encrypted in transit using TLS/SSL.</li>
        </ul>

        <h2>6. Your Rights and Control</h2>
        <p>You may edit or delete note content at any time. You can request permanent account deletion in the app settings.</p>

        <h2>7. Children's Privacy</h2>
        <p>ChillNote is not intended for children under 13, and we do not knowingly collect personal information from children under 13.</p>

        <h2>8. Contact</h2>
        <p>Questions about this policy? Contact us at <strong>support@chillnoteai.com</strong>.</p>
      </article>
    </MarketingShell>
  );
}
