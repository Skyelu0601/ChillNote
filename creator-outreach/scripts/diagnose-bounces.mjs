import { fetchRecentMessages } from "../src/inbox.mjs";

function daysArg() {
  const index = process.argv.indexOf("--days");
  const days = index === -1 ? 3 : Number(process.argv[index + 1]);
  if (!Number.isFinite(days) || days < 1 || days > 30) {
    throw new Error("--days must be between 1 and 30.");
  }
  return days;
}

const since = new Date(Date.now() - daysArg() * 24 * 60 * 60 * 1000);
const messages = await fetchRecentMessages({ since, processedMessageIds: [] });
let bounceCount = 0;

for (const { parsed } of messages) {
  const subject = parsed.subject || "";
  const sender = parsed.from?.value?.[0]?.address || "";
  const text = [parsed.text, subject].filter(Boolean).join("\n");
  const isBounce =
    subject.includes("退信") ||
    sender.toLowerCase() === "no-reply@mailsupport.aliyun.com" ||
    /mail delivery|delivery status notification|undeliver/i.test(subject);
  if (!isBounce) continue;

  const diagnosticLines = text
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .filter((line) =>
      /final-recipient|original-recipient|diagnostic-code|remote-mta|action:|status:|550|552|553|554|5\.[0-9]\.[0-9]|user unknown|not found|does not exist|disabled|blocked|spam|policy|quota|退信原因|收件人|不存在|拒绝|失败/i.test(line),
    )
    .slice(0, 12);
  const addresses = [
    ...new Set(
      (text.match(/[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}/gi) || [])
        .map((value) => value.toLowerCase()),
    ),
  ].filter((value) => value !== "no-reply@mailsupport.aliyun.com");

  bounceCount += 1;
  console.log(`\nBounce ${bounceCount}: ${subject}`);
  if (addresses.length) console.log(`  Addresses: ${addresses.join(", ")}`);
  for (const line of diagnosticLines) console.log(`  ${line.slice(0, 500)}`);
}

console.log(`\nFound ${bounceCount} bounce message(s) in ${messages.length} recent message(s).`);
