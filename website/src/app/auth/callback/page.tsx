"use client";

import { useEffect, useState } from "react";
import { Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { copy } from "@/lib/copy";
import { supabase } from "@/lib/supabase";

export default function AuthCallbackPage() {
  const router = useRouter();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    async function completeSignIn() {
      const params = new URLSearchParams(window.location.search);
      const code = params.get("code");
      const errorDescription = params.get("error_description") ?? params.get("error");

      if (errorDescription) {
        setErrorMessage(errorDescription);
        return;
      }

      if (!code) {
        setErrorMessage(copy.auth.callbackError);
        return;
      }

      const { error } = await supabase.auth.exchangeCodeForSession(code);
      if (error) {
        setErrorMessage(error.message);
        return;
      }

      router.replace("/app");
    }

    void completeSignIn();
  }, [router]);

  return (
    <main className="auth-callback-shell">
      {errorMessage ? (
        <div className="auth-callback-card">
          <img className="auth-logo" src="/assets/chillnote-logo.png" alt="" />
          <p className="form-error">{errorMessage}</p>
          <a className="auth-callback-link" href="/app">
            {copy.auth.backToOptions}
          </a>
        </div>
      ) : (
        <div className="auth-callback-card">
          <Loader2 className="spin" size={22} />
          <p>{copy.auth.callbackLoading}</p>
        </div>
      )}
    </main>
  );
}
