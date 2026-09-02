export const massTikTokEmailActor = "scraper-mind/tiktok-email-scraper";

function takeValue(args, index, flag) {
  const value = args[index + 1]?.trim();
  if (!value || value.startsWith("--")) {
    throw new Error(`${flag} requires a value.`);
  }
  return value;
}

export function parseTikTokEmailArgs(args) {
  const options = {
    keywords: [],
    domains: [],
    location: "",
    maxEmails: 20,
    run: false,
    help: false,
  };

  for (let index = 0; index < args.length; index += 1) {
    const flag = args[index];

    if (flag === "--keyword") {
      options.keywords.push(takeValue(args, index, flag));
      index += 1;
    } else if (flag === "--domain") {
      options.domains.push(takeValue(args, index, flag));
      index += 1;
    } else if (flag === "--location") {
      options.location = takeValue(args, index, flag);
      index += 1;
    } else if (flag === "--max-emails") {
      const rawValue = takeValue(args, index, flag);
      options.maxEmails = Number(rawValue);
      index += 1;
    } else if (flag === "--run") {
      options.run = true;
    } else if (flag === "--help" || flag === "-h") {
      options.help = true;
    } else {
      throw new Error(`Unknown option: ${flag}`);
    }
  }

  if (options.help) return options;
  if (!options.keywords.length) {
    throw new Error("Add at least one --keyword.");
  }
  if (!Number.isInteger(options.maxEmails) || options.maxEmails < 1 || options.maxEmails > 10_000) {
    throw new Error("--max-emails must be an integer between 1 and 10000.");
  }

  if (!options.domains.length) {
    options.domains = ["@gmail.com", "@outlook.com", "@hotmail.com", "@yahoo.com", "@icloud.com"];
  }

  options.domains = options.domains.map((domain) =>
    domain.startsWith("@") ? domain.toLowerCase() : `@${domain.toLowerCase()}`,
  );

  return options;
}

export function buildTikTokEmailInput(options) {
  return {
    keywords: options.keywords,
    location: options.location,
    platform: "TikTok",
    customDomains: options.domains,
    maxEmails: options.maxEmails,
    engine: "legacy",
  };
}

export function deduplicateTikTokEmailResults(items) {
  const seen = new Set();
  const results = [];

  for (const item of items) {
    const email = item.email?.trim().toLowerCase();
    if (!email || seen.has(email)) continue;
    seen.add(email);
    results.push({
      email,
      url: item.url || "",
      title: item.title || "",
      description: item.description || "",
      keyword: item.keyword || "",
      network: item.network || "TikTok",
    });
  }

  return results;
}
