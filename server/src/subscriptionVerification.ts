import type { Express, RequestHandler } from "express";
import type { RevenueCatEntitlementSnapshot } from "./revenueCat.js";

type Dependencies = {
  upsertUser(userId: string): Promise<void>;
  sync(userId: string): Promise<RevenueCatEntitlementSnapshot>;
  effective(userId: string): Promise<{
    tier: "free" | "pro";
    expiresAt: Date | null;
    source: "legacy" | "revenuecat" | null;
  }>;
};

export function registerSubscriptionVerificationRoutes(
  app: Express, auth: RequestHandler, deps: Dependencies
) {
  const refresh: RequestHandler = async (req, res) => {
    const userId = req.userId!;
    try {
      await deps.upsertUser(userId);
      // Deliberately never read req.body. An authenticated request proves account
      // ownership, not an Apple purchase. Old metadata/receipt payloads remain
      // accepted, but cannot select another customer or manufacture an expiry.
      const snapshot = await deps.sync(userId);
      const effective = await deps.effective(userId);
      res.json({
        success: true,
        tier: effective.tier,
        expiresAt: effective.expiresAt?.toISOString() ?? null,
        activeProductId: effective.source === "revenuecat" ? snapshot.productId : null
      });
    } catch {
      // Do not fall back to the caller's metadata when the verifier is unavailable.
      res.status(503).json({ code: "SUBSCRIPTION_VERIFICATION_UNAVAILABLE" });
    }
  };
  app.post("/subscription/verify", auth, refresh);
  app.post("/subscription/revenuecat/sync", auth, refresh);
}
