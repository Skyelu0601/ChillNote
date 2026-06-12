"use client";

import { FormEvent, useState } from "react";
import { ArrowLeft, ArrowRight, Loader2 } from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";
import { copy } from "@/lib/copy";
import { supabase } from "@/lib/supabase";
import { Wordmark } from "./wordmark";
import { OtpInput } from "./otp-input";

type AuthPanelProps = {
  onAuthenticated: () => void;
};

type BusyState = "send" | "verify" | "apple" | "google" | null;
type OAuthProvider = "apple" | "google";
type View = "form" | "code";

const fade = {
  initial: { opacity: 0, y: 10 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -10 },
  transition: { duration: 0.26, ease: [0.16, 1, 0.3, 1] as const },
};

export function AuthPanel({ onAuthenticated }: AuthPanelProps) {
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [view, setView] = useState<View>("form");
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

  async function sendCode(event?: FormEvent) {
    event?.preventDefault();
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
    setCode("");
    setView("code");
  }

  async function verifyCode(submittedCode?: string) {
    setError(null);
    const normalizedEmail = email.trim().toLowerCase();
    const normalizedCode = (submittedCode ?? code).trim();
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

  function backToForm() {
    setView("form");
    setCode("");
    setError(null);
  }

  return (
    <section className="lp-auth" aria-label={copy.auth.title}>
      <a className="lp-auth-home" href="/">
        <ArrowLeft size={15} />
        {copy.auth.backToHome}
      </a>

      <motion.div
        className="lp-auth-card"
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
      >
        <header className="lp-auth-card-head">
          <Wordmark className="lp-auth-wordmark" />
          <p className="lp-auth-subtitle">{copy.auth.subtitle}</p>
        </header>

        <AnimatePresence mode="wait" initial={false}>
          {view === "form" ? (
            <motion.div key="form" className="lp-auth-body" {...fade}>
              <button
                className="lp-auth-provider"
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
                className="lp-auth-provider"
                type="button"
                onClick={() => void signInWithProvider("apple")}
                disabled={busy !== null}
              >
                {busy === "apple" ? <Loader2 className="spin" size={18} /> : <span className="apple-mark" />}
                {copy.auth.appleButton}
              </button>

              <div className="lp-auth-divider">
                <span>{copy.auth.dividerLabel}</span>
              </div>

              <form className="lp-auth-email" onSubmit={sendCode}>
                <label className="lp-auth-label" htmlFor="auth-email">
                  {copy.auth.emailLabel}
                </label>
                <input
                  id="auth-email"
                  className="lp-auth-input"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder={copy.auth.emailPlaceholder}
                  type="email"
                  autoComplete="email"
                />

                {error ? <p className="form-error">{error}</p> : null}

                <button className="lp-auth-submit" type="submit" disabled={busy !== null}>
                  {busy === "send" ? <Loader2 className="spin" size={18} /> : null}
                  {busy === "send" ? copy.auth.sending : copy.auth.sendCode}
                  {busy !== "send" ? <ArrowRight size={17} /> : null}
                </button>
              </form>
            </motion.div>
          ) : (
            <motion.form
              key="code"
              className="lp-auth-body"
              onSubmit={(e) => {
                e.preventDefault();
                void verifyCode();
              }}
              {...fade}
            >
              <p className="lp-auth-code-hint">
                {copy.auth.codeSentTo.replace("{email}", email.trim())}
              </p>

              <OtpInput
                value={code}
                onChange={setCode}
                disabled={busy !== null}
                autoFocus
                onComplete={(full) => void verifyCode(full)}
              />

              {error ? <p className="form-error">{error}</p> : null}

              <button className="lp-auth-submit" type="submit" disabled={busy !== null}>
                {busy === "verify" ? <Loader2 className="spin" size={18} /> : null}
                {busy === "verify" ? copy.auth.verifying : copy.auth.verifyCode}
              </button>

              <button className="lp-auth-back" type="button" onClick={backToForm}>
                <ArrowLeft size={15} />
                {copy.auth.backToOptions}
              </button>
            </motion.form>
          )}
        </AnimatePresence>

        <p className="lp-auth-legal">{copy.auth.legal}</p>
      </motion.div>
    </section>
  );
}
