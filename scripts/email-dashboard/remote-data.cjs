const { PrismaClient, Prisma } = require("@prisma/client");

const prisma = new PrismaClient();

function parseOptions() {
  const raw = process.argv[2] || "";
  if (!/^[A-Za-z0-9_-]{1,2048}$/.test(raw)) throw new Error("Invalid request");
  const options = JSON.parse(Buffer.from(raw, "base64url").toString("utf8"));
  const days = [1, 7, 30, 0].includes(options.days) ? options.days : 1;
  const page = Number.isInteger(options.page) && options.page >= 1 && options.page <= 10000 ? options.page : 1;
  const kind = typeof options.kind === "string" && /^[a-z0-9_]{1,50}$/.test(options.kind) ? options.kind : "";
  const state = ["", "delivered", "accepted", "bounced", "complained", "rejected", "scheduled", "failed", "skipped", "cancelled", "suppressed"].includes(options.state) ? options.state : "";
  const search = typeof options.search === "string" ? options.search.trim().slice(0, 120) : "";
  return { days, page, kind, state, search };
}

async function main() {
  const options = parseOptions();
  const cutoff = options.days ? new Date(Date.now() - options.days * 24 * 60 * 60 * 1000) : null;
  const periodWhere = cutoff ? { createdAt: { gte: cutoff } } : {};
  const groups = await prisma.emailDelivery.groupBy({
    by: ["kind", "status", "providerStatus"],
    where: periodWhere,
    _count: { _all: true }
  });

  const filters = [];
  if (cutoff) filters.push(Prisma.sql`ed."createdAt" >= ${cutoff}`);
  if (options.kind) filters.push(Prisma.sql`ed."kind" = ${options.kind}`);
  if (options.search) filters.push(Prisma.sql`au.email ILIKE ${`%${options.search.replace(/[\\%_]/g, "\\$&")}%`} ESCAPE '\\'`);
  if (options.state === "accepted") filters.push(Prisma.sql`ed."status" = 'sent' AND (ed."providerStatus" IS NULL OR ed."providerStatus" IN ('accepted', 'delayed'))`);
  else if (options.state === "delivered" || options.state === "bounced" || options.state === "complained" || options.state === "rejected") {
    filters.push(Prisma.sql`ed."providerStatus" = ${options.state}`);
  } else if (options.state) filters.push(Prisma.sql`ed."status" = ${options.state}`);

  const where = filters.length ? Prisma.sql`WHERE ${Prisma.join(filters, " AND ")}` : Prisma.empty;
  const [countRows, deliveries] = await Promise.all([
    prisma.$queryRaw(Prisma.sql`
      SELECT COUNT(*)::int AS count
      FROM public."EmailDelivery" ed
      LEFT JOIN auth.users au ON au.id::text = ed."userId"
      ${where}
    `),
    prisma.$queryRaw(Prisma.sql`
      SELECT ed."id", ed."kind", ed."status", ed."providerStatus",
             ed."createdAt", ed."scheduledAt", ed."sentAt", ed."deliveredAt",
             ed."bouncedAt", ed."complainedAt", ed."lastError", au.email
      FROM public."EmailDelivery" ed
      LEFT JOIN auth.users au ON au.id::text = ed."userId"
      ${where}
      ORDER BY ed."createdAt" DESC, ed."id" DESC
      LIMIT 50 OFFSET ${(options.page - 1) * 50}
    `)
  ]);

  process.stdout.write(JSON.stringify({
    fetchedAt: new Date().toISOString(),
    groups: groups.map((group) => ({
      kind: group.kind,
      status: group.status,
      providerStatus: group.providerStatus,
      count: group._count._all
    })),
    count: countRows[0]?.count ?? 0,
    page: options.page,
    pageSize: 50,
    deliveries
  }));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : "Data query failed");
  process.exitCode = 1;
}).finally(() => prisma.$disconnect());
