import type { Express, RequestHandler } from "express";
import type { RevenueCatEntitlementSnapshot } from "./revenueCat.js";
import { subscriptionAccountRef, subscriptionErrorDetails } from "./subscriptionDiagnostics.js";

export type VerificationFailure = {
  event: "subscription_verification_failed";
  accountRef: string;
  stage: "account" | "revenuecat_sync" | "effective_subscription" | "billing_issue";
  elapsedMs: number;
} & ReturnType<typeof subscriptionErrorDetails>;

type Dependencies = {
  upsertUser(userId: string): Promise<void>;
  sync(userId: string): Promise<RevenueCatEntitlementSnapshot>;
  effective(userId: string): Promise<{
    tier: "free" | "pro";
    expiresAt: Date | null;
    source: "legacy" | "revenuecat" | null;
  }>;
  billingIssue(userId: string): Promise<{ store: string; productId: string | null } | null>;
  onFailure?(failure: VerificationFailure): void;
};

export function registerSubscriptionVerificationRoutes(
  app: Express, auth: RequestHandler, deps: Dependencies
) {
  const refresh: RequestHandler = async (req, res) => {
    const userId = req.userId!;
    const startedAt = Date.now();
    let stage: VerificationFailure["stage"] = "account";
    try {
      await deps.upsertUser(userId);
      // Deliberately never read req.body. An authenticated request proves account
      // ownership, not an Apple purchase. Old metadata/receipt payloads remain
      // accepted, but cannot select another customer or manufacture an expiry.
      stage = "revenuecat_sync";
      const snapshot = await deps.sync(userId);
      stage = "effective_subscription";
      const effective = await deps.effective(userId);
      stage = "billing_issue";
      const billingIssue = await deps.billingIssue(userId);
      res.json({
        success: true,
        tier: effective.tier,
        expiresAt: effective.expiresAt?.toISOString() ?? null,
        activeProductId: effective.source === "revenuecat" ? snapshot.productId : null,
        billingIssue
      });
    } catch (error) {
      const failure: VerificationFailure = {
        event: "subscription_verification_failed", accountRef: subscriptionAccountRef(userId),
        stage, elapsedMs: Date.now() - startedAt, ...subscriptionErrorDetails(error)
      };
      // Logging must not change the response contract, including during a logger outage.
      try {
        if (deps.onFailure) deps.onFailure(failure);
        else console.error(JSON.stringify(failure));
      } catch { /* The verifier must still fail closed. */ }
      // Do not fall back to the caller's metadata when the verifier is unavailable.
      res.status(503).json({ code: "SUBSCRIPTION_VERIFICATION_UNAVAILABLE" });
    }
  };
  app.post("/subscription/verify", auth, refresh);
  app.post("/subscription/revenuecat/sync", auth, refresh);
}
