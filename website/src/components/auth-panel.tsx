"use client";

import { FormEvent, useState } from "react";
import { ArrowLeft, CheckCircle2, Loader2, Mail } from "lucide-react";
import { copy } from "@/lib/copy";
import { supabase } from "@/lib/supabase";

type AuthPanelProps = {
  onAuthenticated: () => void;
};

type BusyState = "send" | "verify" | "apple" | "google" | null;
type OAuthProvider = "apple" | "google";

export function AuthPanel({ onAuthenticated }: AuthPanelProps) {
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const [showEmailLogin, setShowEmailLogin] = useState(false);
  const [busy, setBusy] = useState<BusyState>(null);
  const [error, setError] = useState<string | null>(null);

  async function signInWithProvider(provider: OAuthProvider) {
    setError(null);
    setBusy(provider);
    const isApple = provider === "apple";
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
        scopes: isApple ? "email name" : "email profile",
      },
    });
    setBusy(null);
    if (error) {
      setError(error.message);
    }
  }

  async function sendCode(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail) {
      setError(copy.errors.emptyEmail);
      return;
    }
    setBusy("send");
    const { error } = await supabase.auth.signInWithOtp({
      email: normalizedEmail,
      options: { shouldCreateUser: true },
    });
    setBusy(null);
    if (error) {
      setError(error.message);
      return;
    }
    setSent(true);
  }

  async function verifyCode(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const normalizedEmail = email.trim().toLowerCase();
    const normalizedCode = code.trim();
    if (!normalizedEmail) {
      setError(copy.errors.emptyEmail);
      return;
    }
    if (!normalizedCode) {
      setError(copy.errors.emptyCode);
      return;
    }
    setBusy("verify");
    const { error } = await supabase.auth.verifyOtp({
      email: normalizedEmail,
      token: normalizedCode,
      type: "email",
    });
    setBusy(null);
    if (error) {
      setError(error.message);
      return;
    }
    onAuthenticated();
  }

  return (
    <section className="auth-shell" aria-label={copy.auth.title}>
      <div className="auth-stage">
        <div className="auth-brand-panel" aria-hidden="true">
          <div className="auth-preview-card auth-preview-card-primary">
            <span>{copy.auth.previewLabel}</span>
            <strong>{copy.auth.previewTitle}</strong>
            <p>{copy.auth.previewBody}</p>
          </div>
          <div className="auth-preview-card auth-preview-card-secondary">
            <CheckCircle2 size={18} />
            <span>{copy.auth.previewSync}</span>
          </div>
        </div>

        <div className="auth-panel">
          <header className="auth-header">
            <img className="auth-logo" src="/assets/chillnote-logo.png" alt="" />
            <div className="auth-wordmark" aria-label={copy.auth.brandTitle}>
              <span>Chill</span>
              <strong>Note</strong>
            </div>
          </header>

          {showEmailLogin ? (
            <form className="auth-form" onSubmit={sent ? verifyCode : sendCode}>
              {!sent ? (
                <label>
                  <span>{copy.auth.emailLabel}</span>
                  <div className="input-with-icon">
                    <Mail size={17} />
                    <input
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                      placeholder={copy.auth.emailPlaceholder}
                      type="email"
                      autoComplete="email"
                    />
                  </div>
                </label>
              ) : (
                <label>
                  <span>{copy.auth.codeSentTo.replace("{email}", email.trim())}</span>
                  <input
                    className="auth-code-input"
                    value={code}
                    onChange={(event) => setCode(event.target.value)}
                    placeholder={copy.auth.codePlaceholder}
                    inputMode="numeric"
                    autoComplete="one-time-code"
                  />
                </label>
              )}

              {error ? <p className="form-error">{error}</p> : null}

              <button className="auth-primary-button" type="submit" disabled={busy !== null}>
                {busy === "send" || busy === "verify" ? <Loader2 className="spin" size={18} /> : null}
                {sent
                  ? busy === "verify"
                    ? copy.auth.verifying
                    : copy.auth.verifyCode
                  : busy === "send"
                    ? copy.auth.sending
                    : copy.auth.sendCode}
              </button>

              <button
                className="auth-back-button"
                type="button"
                onClick={() => {
                  setShowEmailLogin(false);
                  setSent(false);
                  setCode("");
                  setError(null);
                }}
              >
                <ArrowLeft size={15} />
                {copy.auth.backToOptions}
              </button>
            </form>
          ) : (
            <div className="auth-options">
              <button
                className="auth-provider-button"
                type="button"
                onClick={() => void signInWithProvider("google")}
                disabled={busy !== null}
              >
                {busy === "google" ? (
                  <Loader2 className="spin" size={18} />
                ) : (
                  <img src="/assets/google-g-logo.svg" alt="" />
                )}
                {copy.auth.googleButton}
              </button>

              <button
                className="auth-provider-button auth-provider-button-dark"
                type="button"
                onClick={() => void signInWithProvider("apple")}
                disabled={busy !== null}
              >
                {busy === "apple" ? <Loader2 className="spin" size={18} /> : <span className="apple-mark" />}
                {copy.auth.appleButton}
              </button>

              <button className="auth-email-link" type="button" onClick={() => setShowEmailLogin(true)}>
                {copy.auth.emailButton}
              </button>

              {error ? <p className="form-error">{error}</p> : null}
            </div>
          )}

          <p className="auth-legal">{copy.auth.legal}</p>
        </div>
      </div>
    </section>
  );
}
