import type { Express, RequestHandler } from "express";
import type { PrismaClient } from "@prisma/client";
import { z } from "zod";

export function welcomeContent(tier: string, initialGrant: number | null) {
  if (tier === "pro") return { kind: "welcome_pro", amount: null };
  if (initialGrant != null && initialGrant > 0) return { kind: "welcome_credits", amount: initialGrant };
  return null;
}

export interface InboxDependencies {
  prisma: PrismaClient;
  upsertUser(userId: string): Promise<unknown>;
  resolveTier(userId: string): Promise<string>;
  initialCredits: number;
}

export function registerAppNotificationRoutes(app: Express, auth: RequestHandler, deps: InboxDependencies) {
  app.get("/notifications", auth, async (req, res) => {
    try {
      const userId = req.userId!;
      await deps.upsertUser(userId);
      const tier = await deps.resolveTier(userId);
      const notifications = await deps.prisma.$transaction(async (tx) => {
        const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
        if (user.welcomeNotificationEligible) {
          // An old Auth account's first backend visit is not a new registration.
          const authCreatedAt = Date.parse(req.userCreatedAt ?? "");
          const isNewAccount = Number.isFinite(authCreatedAt)
            && Math.abs(user.createdAt.getTime() - authCreatedAt) <= 24 * 60 * 60 * 1000;
          const existing = await tx.appNotification.findUnique({
            where: { userId_dedupeKey: { userId, dedupeKey: "welcome" } }
          });
          if (existing || isNewAccount) {
            let amount: number | null = null;
            if (tier !== "pro" && !existing) {
              const credits = await tx.userCredits.upsert({
                where: { userId }, update: {},
                create: { userId, balance: deps.initialCredits, initialGrantAmount: deps.initialCredits }
              });
              amount = credits.initialGrantAmount;
            }
            const content = welcomeContent(tier, amount);
            if (!existing && content) {
              await tx.appNotification.upsert({
                where: { userId_dedupeKey: { userId, dedupeKey: "welcome" } },
                update: {}, create: { userId, dedupeKey: "welcome", ...content }
              });
            }
            if (tier === "pro") {
              await tx.appNotification.updateMany({
                where: { userId, dedupeKey: "welcome", kind: "welcome_credits" },
                data: { kind: "welcome_pro", amount: null }
              });
            }
          }
        }
        return tx.appNotification.findMany({ where: { userId }, orderBy: { createdAt: "desc" } });
      });
      res.json({ notifications });
    } catch (error) {
      console.error("Notification inbox unavailable", error);
      res.status(503).json({ error: "NOTIFICATIONS_UNAVAILABLE" });
    }
  });
  app.post("/notifications/read", auth, async (req, res) => {
    const parsed = z.object({ ids: z.array(z.string().uuid()).min(1).max(100) }).safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "INVALID_NOTIFICATION_IDS" });
      return;
    }
    try {
      // Only acknowledge rendered IDs owned by this account, not future messages.
      await deps.prisma.appNotification.updateMany({
        where: { userId: req.userId!, id: { in: parsed.data.ids }, readAt: null },
        data: { readAt: new Date() }
      });
      res.json({ success: true });
    } catch (error) {
      console.error("Notification read state unavailable", error);
      res.status(503).json({ error: "NOTIFICATIONS_UNAVAILABLE" });
    }
  });
}
