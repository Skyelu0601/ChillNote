import type { Metadata } from "next";
import { MarketingShell } from "@/components/marketing-shell";

export const metadata: Metadata = {
  title: "Delete Your ChillScript Account",
  description: "Delete your ChillScript account and the data associated with it.",
};

const deletionEmail =
  "mailto:support@chillnoteai.com?subject=ChillScript%20account%20deletion%20request&body=Please%20delete%20the%20ChillScript%20account%20associated%20with%20this%20email%20address.";

export default function DeleteAccountPage() {
  return (
    <MarketingShell>
      <article className="legal-document">
        <p className="eyebrow">Account and data</p>
        <h1>Delete your ChillScript account</h1>
        <p>
          You can permanently delete your ChillScript account and its associated data either in the app or by sending
          us a deletion request.
        </p>

        <h2>Delete your account in the app</h2>
        <ol>
          <li>Open ChillScript and sign in.</li>
          <li>Open <strong>Settings</strong>.</li>
          <li>Select <strong>Delete account</strong> and confirm.</li>
        </ol>
        <p>
          This deletes your account, synced notes and topics, and other data associated with your ChillScript account. The
          app also removes that account&apos;s local notes and pending recordings from the device.
        </p>

        <h2>Request deletion without the app</h2>
        <p>
          Email us from the address associated with your ChillScript account. This helps us verify that the request came
          from the account owner. We will never ask you to send your password or verification code.
        </p>
        <p>
          <a className="nav-pill" href={deletionEmail}>Email an account deletion request</a>
        </p>
        <p>
          If a local copy remains on a device you no longer use, uninstall ChillScript or clear its app storage on that
          device.
        </p>

        <h2>Subscriptions</h2>
        <p>
          Deleting your ChillScript account does not automatically cancel a subscription managed by an app store.
          Cancel it separately in your <a className="inline-link" href="https://play.google.com/store/account/subscriptions">Google Play subscriptions</a>
          {" "}or in your Apple Account subscription settings to prevent future renewal.
        </p>

        <h2>Questions</h2>
        <p>
          For questions about deletion or retained records required for security, fraud prevention, or legal compliance,
          contact <strong>support@chillnoteai.com</strong> or read our <a className="inline-link" href="/privacy">Privacy Policy</a>.
        </p>
      </article>
    </MarketingShell>
  );
}
