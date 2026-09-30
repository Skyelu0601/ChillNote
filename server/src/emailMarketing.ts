export type MarketingWinbackKind =
  | "marketing_winback_1"
  | "marketing_winback_2"
  | "marketing_winback_3";

export type MarketingWinbackDeliveryState = {
  kind: MarketingWinbackKind;
  status: string;
  sentAt: Date | null;
};

export type MarketingWinbackSchedule = {
  kind: MarketingWinbackKind;
  scheduledAt: Date;
};

const MARKETING_WINBACK_KINDS = new Set<MarketingWinbackKind>([
  "marketing_winback_1",
  "marketing_winback_2",
  "marketing_winback_3"
]);

const DAY_MS = 24 * 60 * 60 * 1_000;

export function isMarketingWinbackKind(value: string): value is MarketingWinbackKind {
  return MARKETING_WINBACK_KINDS.has(value as MarketingWinbackKind);
}

export function marketingWinbackKinds(): MarketingWinbackKind[] {
  return [...MARKETING_WINBACK_KINDS];
}

export function nextMarketingWinbackSchedule(input: {
  lastActivityAt: Date;
  deliveries: MarketingWinbackDeliveryState[];
  now?: Date;
}): MarketingWinbackSchedule | null {
  const now = input.now ?? new Date();
  const byKind = new Map(input.deliveries.map((delivery) => [delivery.kind, delivery]));
  const first = byKind.get("marketing_winback_1");
  const second = byKind.get("marketing_winback_2");
  const third = byKind.get("marketing_winback_3");

  if (third || second && second.status !== "sent" || first && first.status !== "sent") return null;

  if (!first) {
    const scheduledAt = new Date(input.lastActivityAt.getTime() + 7 * DAY_MS);
    return scheduledAt <= now ? { kind: "marketing_winback_1", scheduledAt: now } : null;
  }

  if (!second) {
    if (!first.sentAt) return null;
    const scheduledAt = new Date(first.sentAt.getTime() + 7 * DAY_MS);
    return scheduledAt <= now ? { kind: "marketing_winback_2", scheduledAt: now } : null;
  }

  if (!third) {
    if (!second.sentAt) return null;
    const scheduledAt = new Date(second.sentAt.getTime() + 16 * DAY_MS);
    return scheduledAt <= now ? { kind: "marketing_winback_3", scheduledAt: now } : null;
  }

  return null;
}
