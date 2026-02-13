import { prisma } from "./db.js";
import type { Prisma } from "@prisma/client";

const INVITE_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const INVITE_CODE_LENGTH = Math.max(4, Number(process.env.INVITE_CODE_LENGTH ?? 8));
const INVITE_REWARD_DAYS = Math.max(1, Number(process.env.INVITE_REWARD_DAYS ?? 7));
const INVITE_BIND_WINDOW_DAYS = Math.max(1, Number(process.env.INVITE_BIND_WINDOW_DAYS ?? 7));
const INVITE_MONTHLY_CAP = Math.max(1, Number(process.env.INVITE_MONTHLY_CAP ?? 3));
const DAY_MS = 24 * 60 * 60 * 1000;

export class InviteError extends Error {
  statusCode: number;
  code: string;

  constructor(statusCode: number, code: string, message: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}

function randomInviteCode(length = INVITE_CODE_LENGTH): string {
  let output = "";
  for (let i = 0; i < length; i += 1) {
    const index = Math.floor(Math.random() * INVITE_CODE_ALPHABET.length);
    output += INVITE_CODE_ALPHABET[index];
  }
  return output;
}

function startOfUtcMonth(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1, 0, 0, 0, 0));
}

function startOfNextUtcMonth(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 1, 0, 0, 0, 0));
}

function resolveGrantExpiry(now: Date, existingExpiry?: Date | null): Date {
  const base = existingExpiry && existingExpiry.getTime() > now.getTime() ? existingExpiry : now;
  return new Date(base.getTime() + INVITE_REWARD_DAYS * DAY_MS);
}

async function createUniqueInviteCode(userId: string): Promise<string> {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const candidate = randomInviteCode();
    const exists = await prisma.inviteCode.findUnique({ where: { code: candidate }, select: { id: true } });
    if (!exists) {
      await prisma.inviteCode.create({
        data: {
          userId,
          code: candidate,
          isActive: true
        }
      });
      return candidate;
    }
  }

  throw new InviteError(500, "INVITE_CODE_EXHAUSTED", "Failed to allocate invite code");
}

export async function getOrCreateInviteCode(userId: string): Promise<string> {
  const existing = await prisma.inviteCode.findUnique({
    where: { userId },
    select: { code: true, isActive: true }
  });

  if (existing?.isActive) {
    return existing.code;
  }

  if (existing && !existing.isActive) {
    for (let attempt = 0; attempt < 12; attempt += 1) {
      const candidate = randomInviteCode();
      const codeExists = await prisma.inviteCode.findUnique({ where: { code: candidate }, select: { id: true } });
      if (codeExists) {
        continue;
      }
      await prisma.inviteCode.update({
        where: { userId },
        data: { code: candidate, isActive: true }
      });
      return candidate;
    }

    throw new InviteError(500, "INVITE_CODE_EXHAUSTED", "Failed to allocate invite code");
  }

  return createUniqueInviteCode(userId);
}

export async function getInviteMonthlyRewardCount(userId: string, now = new Date()): Promise<number> {
  const monthStart = startOfUtcMonth(now);
  const nextMonthStart = startOfNextUtcMonth(now);

  return prisma.invite.count({
    where: {
      inviterId: userId,
      status: "rewarded",
      rewardedAt: {
        gte: monthStart,
        lt: nextMonthStart
      }
    }
  });
}

async function applyRewardGrant(
  tx: Prisma.TransactionClient,
  userId: string,
  inviteId: string,
  role: "inviter" | "invitee",
  now: Date
): Promise<Date> {
  const user = await tx.user.findUnique({
    where: { id: userId },
    select: { subscriptionTier: true, subscriptionExpiresAt: true }
  });

  if (!user) {
    throw new InviteError(404, "USER_NOT_FOUND", "User not found");
  }

  const nextExpiry = resolveGrantExpiry(now, user.subscriptionExpiresAt);

  await tx.user.update({
    where: { id: userId },
    data: {
      subscriptionTier: "pro",
      subscriptionExpiresAt: nextExpiry
    }
  });

  await tx.membershipGrantLedger.create({
    data: {
      userId,
      inviteId,
      role,
      days: INVITE_REWARD_DAYS,
      beforeTier: user.subscriptionTier,
      beforeExpiresAt: user.subscriptionExpiresAt,
      afterTier: "pro",
      afterExpiresAt: nextExpiry
    }
  });

  return nextExpiry;
}

export async function bindInviteCode(params: {
  inviteeId: string;
  inviteeCreatedAt: Date;
  code: string;
  now?: Date;
}): Promise<{
  inviteId: string;
  rewardDays: number;
  inviterNewExpiresAt: string | null;
  inviteeNewExpiresAt: string | null;
  monthlyCap: number;
}> {
  const now = params.now ?? new Date();
  const normalizedCode = params.code.trim().toUpperCase();

  if (!/^[A-Z0-9]{4,32}$/.test(normalizedCode)) {
    throw new InviteError(400, "INVALID_INVITE_CODE", "Invalid invite code");
  }

  const bindDeadline = new Date(params.inviteeCreatedAt.getTime() + INVITE_BIND_WINDOW_DAYS * DAY_MS);
  if (bindDeadline.getTime() < now.getTime()) {
    throw new InviteError(422, "INVITE_BIND_WINDOW_EXPIRED", "Invite binding window expired");
  }

  const inviteCode = await prisma.inviteCode.findUnique({
    where: { code: normalizedCode },
    select: { id: true, code: true, isActive: true, userId: true }
  });

  if (!inviteCode || !inviteCode.isActive) {
    throw new InviteError(400, "INVITE_CODE_NOT_FOUND", "Invite code not found");
  }

  if (inviteCode.userId === params.inviteeId) {
    throw new InviteError(409, "SELF_INVITE_BLOCKED", "Cannot use your own invite code");
  }

  const existingInvite = await prisma.invite.findUnique({
    where: { inviteeId: params.inviteeId },
    select: {
      id: true,
      status: true,
      inviteCode: true
    }
  });

  if (existingInvite) {
    if (existingInvite.status === "rewarded" && existingInvite.inviteCode === normalizedCode) {
      const [inviterUser, inviteeUser] = await Promise.all([
        prisma.user.findUnique({ where: { id: inviteCode.userId }, select: { subscriptionExpiresAt: true } }),
        prisma.user.findUnique({ where: { id: params.inviteeId }, select: { subscriptionExpiresAt: true } })
      ]);

      return {
        inviteId: existingInvite.id,
        rewardDays: INVITE_REWARD_DAYS,
        inviterNewExpiresAt: inviterUser?.subscriptionExpiresAt?.toISOString() ?? null,
        inviteeNewExpiresAt: inviteeUser?.subscriptionExpiresAt?.toISOString() ?? null,
        monthlyCap: INVITE_MONTHLY_CAP
      };
    }

    throw new InviteError(409, "INVITEE_ALREADY_BOUND", "Invitee already bound to an invite code");
  }

  const monthStart = startOfUtcMonth(now);
  const nextMonthStart = startOfNextUtcMonth(now);
  const rewardedCount = await prisma.invite.count({
    where: {
      inviterId: inviteCode.userId,
      status: "rewarded",
      rewardedAt: {
        gte: monthStart,
        lt: nextMonthStart
      }
    }
  });

  if (rewardedCount >= INVITE_MONTHLY_CAP) {
    throw new InviteError(409, "INVITER_MONTHLY_CAP_REACHED", "Inviter has reached monthly reward cap");
  }

  return prisma.$transaction(async (tx) => {
    const invite = await tx.invite.create({
      data: {
        inviterId: inviteCode.userId,
        inviteeId: params.inviteeId,
        inviteCodeId: inviteCode.id,
        inviteCode: inviteCode.code,
        status: "bound",
        rewardDays: INVITE_REWARD_DAYS,
        boundAt: now
      },
      select: { id: true }
    });

    const [inviterNewExpiry, inviteeNewExpiry] = await Promise.all([
      applyRewardGrant(tx, inviteCode.userId, invite.id, "inviter", now),
      applyRewardGrant(tx, params.inviteeId, invite.id, "invitee", now)
    ]);

    await tx.invite.update({
      where: { id: invite.id },
      data: {
        status: "rewarded",
        rewardedAt: now
      }
    });

    return {
      inviteId: invite.id,
      rewardDays: INVITE_REWARD_DAYS,
      inviterNewExpiresAt: inviterNewExpiry.toISOString(),
      inviteeNewExpiresAt: inviteeNewExpiry.toISOString(),
      monthlyCap: INVITE_MONTHLY_CAP
    };
  });
}

export function getInviteConfig() {
  return {
    rewardDays: INVITE_REWARD_DAYS,
    bindWindowDays: INVITE_BIND_WINDOW_DAYS,
    monthlyCap: INVITE_MONTHLY_CAP
  };
}
