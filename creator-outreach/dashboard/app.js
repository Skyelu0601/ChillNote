const state = {
  data: null,
  plan: null,
  activeJob: null,
  tableLimit: 18,
  modalAction: null,
  language: new URLSearchParams(window.location.search).get("lang") === "en" ? "en" : (localStorage.getItem("outreach-language") || "zh"),
};

if (!['zh', 'en'].includes(state.language)) state.language = 'zh';

const translations = {
  zh: {
    backToTop: "返回顶部", language: "语言", localOnly: "只在本机运行", refresh: "刷新数据",
    campaignTitle: "你想找哪类创作者？", maxCost: "最多约 ${amount}", searchKeywords: "搜索关键词",
    keywordPlaceholder: "例如：UGC creator tips", multiKeywords: "多个关键词可换行或用逗号分隔", suggestedKeywords: "推荐关键词",
    advancedSettings: "高级设置", maxResults: "最多抓取", locationOptional: "地区（可选）", locationPlaceholder: "例如：United States",
    viewPlan: "查看计划", startDiscovery: "开始发现创作者", workflowTitle: "自动化流程", discovery: "TikTok 发现",
    sourceFilter: "来源过滤", directProfilesOnly: "只接受 /@username", validateReview: "验证与审核", dedupeCheck: "去重 · 邮箱检查",
    monitoredSend: "监测发送", sendInterval: "60–120 秒间隔", partnerConversion: "合作转化", codeAffiliate: "首封注册 · 第二封一年 Pro",
    sendProtection: "发送保护已开启", confirmationRequired: "付费、群发和兑换码邮件都需要确认。", outreachOverview: "推广数据概览",
    contacts: "联系人", allHistory: "全部历史记录", sent: "已发送", firstEmail: "第一封邮件", replied: "已回复",
    awaitingPartner: "等待合作处理", bounced: "已退信", noRecontact: "自动停止再次联系", pendingSend: "待发送",
    nextActions: "接下来做什么", approveContacts: "批准待发送联系人", sendFirstEmail: "发送第一封邮件", syncReplies: "同步回复与退信",
    last14Days: "读取最近 14 天的邮箱动态", viewTemplate: "查看第一封邮件模板", taskProgress: "任务进度",
    activityEmptyOne: "开始抓取、发送或同步后，", activityEmptyTwo: "实时进度会显示在这里。", partnerReplies: "回复与合作转化",
    partnerHelp: "首封直接提供 30% Affiliate 注册入口；核实注册后，第二封发送一年 Pro。", contactRecords: "联系人记录", searchContacts: "搜索邮箱或账号",
    filterContactStatus: "筛选联系人状态", allStatuses: "全部状态", failed: "失败", creator: "创作者", keyword: "关键词",
    emailStatus: "邮箱状态", sendStatus: "发送状态", source: "来源", showMore: "显示更多", localFooter: "数据保存在你的电脑上 · 不公开部署",
    close: "关闭", confirmAction: "确认操作", cancel: "取消", confirm: "确认", emailPreview: "邮件预览", processing: "处理中…",
    sendPaused: "发送已暂停，需确认恢复", readyForReview: "可进入审核与发送", waitingReview: "{count} 位联系人等待审核",
    noWaitingReview: "当前没有待审核联系人", eligibleSend: "{count} 封可进入监测发送", noPendingEmails: "当前没有待发送邮件",
    running: "运行中", protected: "已保护", ready: "就绪", statusSent: "已发送", statusPending: "待发送", statusBounced: "已退信",
    statusFailed: "发送失败", statusBlocked: "已阻止", unknown: "未知", valid: "有效", accepted: "可接收", mxOnly: "仅 MX",
    invalid: "无效", unchecked: "未检查", viewTikTok: "查看 TikTok ↗", noContacts: "没有符合条件的联系人。",
    tableCount: "显示 {visible} / {total} 位联系人", unassignedCode: "尚未分配兑换码", assignedCode: "兑换码已分配，等待发送",
    partnerEmailSent: "合作邮件已发送 · {date}", assignCode: "分配兑换码", sendPartnerEmail: "发送合作邮件", sentComplete: "已完成发送",
    redemption: "兑换：{status}", viewProfile: "查看公开资料", noRepliesOne: "还没有收到创作者回复。", noRepliesTwo: "点击“同步回复与退信”获取最新状态。",
    noTask: "暂无任务", taskWaiting: "任务已启动，等待输出…", completed: "已完成", stopped: "已停止", planReady: "计划已准备",
    maxResultsPlan: "最多 {count} 个结果", ruleDirect: "只接受来源路径以 /@username 开头的 TikTok 页面",
    ruleExclude: "自动去重并排除 Discover、Tag、Search 和跳转页面", ruleNoAutoSend: "新联系人先保存为未批准，不会自动发送邮件",
    jobStarted: "{label}已启动", jobCompleted: "{label}已完成", jobStopped: "{label}已停止", enterKeywords: "请先输入关键词。",
    paidDiscoveryTitle: "确认开始 TikTok 抓取", paidDiscoveryDescription: "Apify 最多返回 <strong>{count}</strong> 个结果，最高结果费用约 <strong>${amount}</strong>。抓取完成后不会自动发邮件。",
    enterPhrase: "输入 {phrase}", beginScrape: "开始抓取", approveTitle: "批准 {count} 位联系人",
    approveDescription: "批准只会更新本地审核状态，不会发送邮件。Discover、Tag 和非 /@username 来源已经被自动排除。", approveConfirm: "确认批准",
    resumePrompt: "发送保护当前已暂停。再输入 RESUME", monitoredSendTitle: "监测发送 {count} 封邮件",
    sendDescription: "邮件间隔为 60–120 秒。地址不存在会跳过；出现 spam 或 SMTP 错误会立即停止。", beginSend: "开始发送",
    waitForTask: "请等待当前任务完成。", firstEmailTitle: "第一封邮件", assignYearCode: "分配一年兑换码",
    assignDescription: "请先核实 <strong>{handle}</strong> 的真实姓名。系统会分配一个未使用的 Apple One-Time Use Code。", creatorName: "创作者姓名",
    sendCodeAffiliate: "发送一年 Pro", partnerDescription: "邮件会在原对话线程中回复，只在 Affiliate 注册核实后发送一年 Pro 兑换链接。",
    emailVersion: "邮件版本", ugcVersion: "UGC 个性化版本", defaultVersion: "通用版本", publicProfile: "公开资料",
    readingProfile: "正在读取 TikTok 公开主页…", followers: "粉丝", totalLikes: "总点赞", videos: "视频", region: "地区", noPublicBio: "公开简介暂无内容",
    actionFailed: "操作失败。", jobDiscover: "抓取 {value}", jobApprove: "批准 {count} 位联系人", jobSend: "监测发送 {count} 封邮件",
    jobSync: "同步回复与退信", jobAssign: "为 {name} 分配兑换码", jobPartnerSend: "发送合作邮件给 {email}",
    markJoined: "核实已加入 Affiliate", assignPartner: "分配一年 Pro 码", sendPartnerCode: "发送一年 Pro", manualReview: "需要人工审核回复",
    affiliateLink: "创作者的专属 Affiliate 链接", lifecycleJoined: "已加入 Affiliate", registrationReported: "对方称已完成注册",
    joinDescription: "请先在 Affiliate 平台核实会员，并记录创作者的专属链接。", partnerCodeDescription: "Affiliate 注册已经核实；第二封邮件会发送一年 Pro 兑换码和专属链接。",
    verifySignup: "等待核实 Affiliate 注册"
  },
  en: {
    backToTop: "Back to top", language: "Language", localOnly: "Runs locally only", refresh: "Refresh data",
    campaignTitle: "What kind of creators are you looking for?", maxCost: "Up to about ${amount}", searchKeywords: "Search keywords",
    keywordPlaceholder: "e.g. UGC creator tips", multiKeywords: "Separate multiple keywords with commas or new lines", suggestedKeywords: "Suggested keywords",
    advancedSettings: "Advanced settings", maxResults: "Maximum results", locationOptional: "Location (optional)", locationPlaceholder: "e.g. United States",
    viewPlan: "Preview plan", startDiscovery: "Discover creators", workflowTitle: "Automated workflow", discovery: "TikTok discovery",
    sourceFilter: "Source filtering", directProfilesOnly: "Only /@username sources", validateReview: "Validation & review", dedupeCheck: "Deduplication · Email checks",
    monitoredSend: "Monitored sending", sendInterval: "60–120 second intervals", partnerConversion: "Partner conversion", codeAffiliate: "Signup first · one year of Pro second",
    sendProtection: "Sending protection is on", confirmationRequired: "Paid runs, bulk sends, and offer-code emails all require confirmation.", outreachOverview: "Outreach overview",
    contacts: "Contacts", allHistory: "All historical records", sent: "Sent", firstEmail: "First email", replied: "Replied",
    awaitingPartner: "Awaiting partner handling", bounced: "Bounced", noRecontact: "Automatically blocked from recontact", pendingSend: "Ready to send",
    nextActions: "Next actions", approveContacts: "Approve pending contacts", sendFirstEmail: "Send first email", syncReplies: "Sync replies & bounces",
    last14Days: "Read mailbox activity from the last 14 days", viewTemplate: "View first-email template", taskProgress: "Task progress",
    activityEmptyOne: "Start a discovery, send, or sync task", activityEmptyTwo: "and live progress will appear here.", partnerReplies: "Replies & partner conversion",
    partnerHelp: "The first email links to the 30% Affiliate Program; the second sends one year of Pro after signup is verified.", contactRecords: "Contact records", searchContacts: "Search email or handle",
    filterContactStatus: "Filter contact status", allStatuses: "All statuses", failed: "Failed", creator: "Creator", keyword: "Keyword",
    emailStatus: "Email status", sendStatus: "Send status", source: "Source", showMore: "Show more", localFooter: "Data stays on your computer · Not publicly deployed",
    close: "Close", confirmAction: "Confirm action", cancel: "Cancel", confirm: "Confirm", emailPreview: "Email preview", processing: "Working…",
    sendPaused: "Sending paused — confirmation required", readyForReview: "Ready for review and sending", waitingReview: "{count} contacts awaiting review",
    noWaitingReview: "No contacts are awaiting review", eligibleSend: "{count} emails ready for monitored sending", noPendingEmails: "No emails are ready to send",
    running: "Running", protected: "Protected", ready: "Ready", statusSent: "Sent", statusPending: "Pending", statusBounced: "Bounced",
    statusFailed: "Send failed", statusBlocked: "Blocked", unknown: "Unknown", valid: "Valid", accepted: "Accepted", mxOnly: "MX only",
    invalid: "Invalid", unchecked: "Unchecked", viewTikTok: "View TikTok ↗", noContacts: "No contacts match these filters.",
    tableCount: "Showing {visible} of {total} contacts", unassignedCode: "No offer code assigned", assignedCode: "Offer code assigned — ready to send",
    partnerEmailSent: "Partner email sent · {date}", assignCode: "Assign offer code", sendPartnerEmail: "Send partner email", sentComplete: "Email sent",
    redemption: "Redeemed: {status}", viewProfile: "View public profile", noRepliesOne: "No creator replies yet.", noRepliesTwo: "Select “Sync replies & bounces” to fetch the latest status.",
    noTask: "No active task", taskWaiting: "Task started — waiting for output…", completed: "Completed", stopped: "Stopped", planReady: "Plan ready",
    maxResultsPlan: "Up to {count} results", ruleDirect: "Accept only TikTok source paths beginning with /@username",
    ruleExclude: "Deduplicate automatically and exclude Discover, Tag, Search, and redirect pages", ruleNoAutoSend: "Save new contacts as unapproved; never send automatically",
    jobStarted: "{label} started", jobCompleted: "{label} completed", jobStopped: "{label} stopped", enterKeywords: "Enter at least one keyword first.",
    paidDiscoveryTitle: "Confirm TikTok discovery", paidDiscoveryDescription: "Apify will return up to <strong>{count}</strong> results, with an estimated maximum result fee of <strong>${amount}</strong>. Emails will not be sent automatically.",
    enterPhrase: "Type {phrase}", beginScrape: "Start discovery", approveTitle: "Approve {count} contacts",
    approveDescription: "Approval only changes the local review status; it does not send email. Discover, Tag, and non-/@username sources are already excluded.", approveConfirm: "Approve contacts",
    resumePrompt: "Sending protection is paused. Also type RESUME", monitoredSendTitle: "Send {count} monitored emails",
    sendDescription: "Emails are spaced 60–120 seconds apart. Missing addresses are skipped; any spam or SMTP error stops the run immediately.", beginSend: "Start sending",
    waitForTask: "Wait for the current task to finish.", firstEmailTitle: "First email", assignYearCode: "Assign one-year offer code",
    assignDescription: "First verify the real name for <strong>{handle}</strong>. The system will assign an unused Apple One-Time Use Code.", creatorName: "Verified creator name",
    sendCodeAffiliate: "Send one year of Pro", partnerDescription: "This replies in the existing thread with a one-year Pro code only after Affiliate signup is verified.",
    emailVersion: "Email version", ugcVersion: "UGC personalized version", defaultVersion: "General version", publicProfile: "Public profile",
    readingProfile: "Reading the public TikTok profile…", followers: "Followers", totalLikes: "Total likes", videos: "Videos", region: "Region", noPublicBio: "No public bio available",
    actionFailed: "Action failed.", jobDiscover: "Discovering {value}", jobApprove: "Approving {count} contacts", jobSend: "Sending {count} monitored emails",
    jobSync: "Syncing replies & bounces", jobAssign: "Assigning an offer code to {name}", jobPartnerSend: "Sending partner email to {email}",
    markJoined: "Verify Affiliate signup", assignPartner: "Assign one-year Pro code", sendPartnerCode: "Send one year of Pro", manualReview: "Reply needs manual review",
    affiliateLink: "Creator's personal Affiliate link", lifecycleJoined: "Affiliate joined", registrationReported: "Creator reported signup complete",
    joinDescription: "First verify the member in the Affiliate platform and record their personal link.", partnerCodeDescription: "Affiliate signup is verified; the second email sends the one-year Pro code and personal link.",
    verifySignup: "Verify Affiliate signup"
  }
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

function t(key, variables = {}) {
  let value = translations[state.language]?.[key] || translations.zh[key] || key;
  for (const [name, replacement] of Object.entries(variables)) value = value.replaceAll(`{${name}}`, String(replacement));
  return value;
}

function applyLanguage() {
  document.documentElement.lang = state.language === "en" ? "en" : "zh-CN";
  $$('[data-i18n]').forEach((element) => { element.textContent = t(element.dataset.i18n); });
  $$('[data-i18n-placeholder]').forEach((element) => { element.placeholder = t(element.dataset.i18nPlaceholder); });
  $$('[data-i18n-aria-label]').forEach((element) => { element.setAttribute("aria-label", t(element.dataset.i18nAriaLabel)); });
  $$('[data-i18n-title]').forEach((element) => { element.title = t(element.dataset.i18nTitle); });
  $$('[data-language]').forEach((button) => {
    const active = button.dataset.language === state.language;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", String(active));
  });
  const url = new URL(window.location.href);
  if (state.language === "en") url.searchParams.set("lang", "en");
  else url.searchParams.delete("lang");
  window.history.replaceState({}, "", url);
  localStorage.setItem("outreach-language", state.language);
  if (state.data) {
    renderStats();
    renderContacts();
    renderReplies();
    renderJob(state.data.activeJob || state.activeJob);
  }
  if (state.plan) renderPlanPreview();
  const count = Math.max(1, Math.min(105, Number($("#maxEmailsInput").value) || 50));
  $("#costBadge").textContent = t("maxCost", { amount: (count * .0025).toFixed(2) });
}

function escapeHtml(value = "") {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatDate(value) {
  if (!value) return "—";
  return new Intl.DateTimeFormat(state.language === "en" ? "en-US" : "zh-CN", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function compactNumber(value) {
  if (value === null || value === undefined) return "—";
  return new Intl.NumberFormat(state.language === "en" ? "en-US" : "zh-CN", { notation: "compact", maximumFractionDigits: 1 }).format(value);
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { "content-type": "application/json", ...(options.headers || {}) },
  });
  const payload = await response.json();
  if (!response.ok) {
    const error = new Error(payload.error || t("actionFailed"));
    error.payload = payload;
    error.status = response.status;
    throw error;
  }
  return payload;
}

function toast(message, type = "success") {
  const item = document.createElement("div");
  item.className = `toast ${type === "error" ? "error" : ""}`;
  item.textContent = message;
  $("#toastRegion").append(item);
  setTimeout(() => item.remove(), 4200);
}

function setBusy(button, busy, label = t("processing")) {
  if (!button) return;
  if (busy) {
    button.dataset.original = button.innerHTML;
    button.textContent = label;
    button.disabled = true;
  } else {
    button.innerHTML = button.dataset.original || button.innerHTML;
    button.disabled = false;
  }
}

function renderStats() {
  const summary = state.data.summary;
  $("#totalStat").textContent = summary.total;
  $("#sentStat").textContent = summary.sent;
  $("#replyStat").textContent = summary.replied;
  $("#bounceStat").textContent = summary.bounced;
  $("#pendingStat").textContent = summary.eligible;
  $("#pauseStat").textContent = state.data.paused ? t("sendPaused") : t("readyForReview");
  $("#approveHelp").textContent = summary.pending
    ? t("waitingReview", { count: summary.pending })
    : t("noWaitingReview");
  $("#sendHelp").textContent = summary.eligible
    ? t("eligibleSend", { count: summary.eligible })
    : t("noPendingEmails");
  $("#approveButton").disabled = summary.pending === 0 || Boolean(state.activeJob);
  $("#sendButton").disabled = summary.eligible === 0 || Boolean(state.activeJob);
  $("#subjectHelp").textContent = state.data.subject;
  const healthDot = $("#healthDot");
  healthDot.textContent = state.activeJob ? t("running") : state.data.paused ? t("protected") : t("ready");
}

function statusLabel(lead) {
  if (lead.reply_status === "replied") return [t("replied"), "replied"];
  const labels = {
    sent: t("statusSent"),
    pending: t("statusPending"),
    bounced: t("statusBounced"),
    failed: t("statusFailed"),
    blocked: t("statusBlocked"),
  };
  return [labels[lead.status] || lead.status || t("unknown"), lead.status || "pending"];
}

function emailStatusLabel(value) {
  const labels = {
    valid: t("valid"),
    accepted: t("accepted"),
    mx_only: t("mxOnly"),
    invalid: t("invalid"),
    unknown: t("unknown"),
    unchecked: t("unchecked"),
  };
  return labels[value] || value || "—";
}

function displayJobLabel(label = "") {
  if (state.language !== "en") return label;
  let match = label.match(/^抓取 (.+)$/);
  if (match) return t("jobDiscover", { value: match[1] });
  match = label.match(/^批准 (\d+) 位联系人$/);
  if (match) return t("jobApprove", { count: match[1] });
  match = label.match(/^监测发送 (\d+) 封邮件$/);
  if (match) return t("jobSend", { count: match[1] });
  if (label === "同步回复与退信") return t("jobSync");
  match = label.match(/^为 (.+) 分配兑换码$/);
  if (match) return t("jobAssign", { name: match[1] });
  match = label.match(/^发送合作邮件给 (.+)$/);
  if (match) return t("jobPartnerSend", { email: match[1] });
  return label;
}

function renderContacts() {
  const query = $("#contactSearch").value.trim().toLowerCase();
  const filter = $("#statusFilter").value;
  const filtered = state.data.leads.filter((lead) => {
    const haystack = `${lead.email} ${lead.handle} ${lead.source_keyword}`.toLowerCase();
    const matchesQuery = !query || haystack.includes(query);
    const matchesFilter =
      filter === "all" ||
      (filter === "replied" ? lead.reply_status === "replied" : lead.status === filter);
    return matchesQuery && matchesFilter;
  });
  const visible = filtered.slice(0, state.tableLimit);
  $("#contactsBody").innerHTML = visible.length
    ? visible.map((lead) => {
        const [label, className] = statusLabel(lead);
        return `<tr>
          <td class="contact-name"><strong>${escapeHtml(lead.handle || "Unknown")}</strong><small>${escapeHtml(lead.email)}</small></td>
          <td>${escapeHtml(lead.source_keyword || "—")}</td>
          <td><span class="status-pill ${escapeHtml(lead.email_status)}">${escapeHtml(emailStatusLabel(lead.email_status))}</span></td>
          <td><span class="status-pill ${escapeHtml(className)}">${escapeHtml(label)}</span></td>
          <td><a class="source-link" href="${escapeHtml(lead.email_source)}" target="_blank" rel="noreferrer">${escapeHtml(t("viewTikTok"))}</a></td>
        </tr>`;
      }).join("")
    : `<tr><td colspan="5">${escapeHtml(t("noContacts"))}</td></tr>`;
  $("#tableCount").textContent = t("tableCount", { visible: Math.min(visible.length, filtered.length), total: filtered.length });
  $("#showMoreButton").classList.toggle("hidden", visible.length >= filtered.length);
}

function creatorDisplayName(lead) {
  const assignment = state.data.assignments.find((item) => item.email === lead.email && item.kind === "partner");
  return assignment?.creator_name || (lead.creator_name && lead.creator_name !== "there" ? lead.creator_name : lead.handle);
}

function renderReplies() {
  const replies = state.data.replies;
  $("#replyGrid").innerHTML = replies.length
    ? replies.map((lead) => {
        const name = creatorDisplayName(lead) || "Creator";
        const initial = name.replace("@", "").slice(0, 1).toUpperCase();
        let lifecycleText = t("manualReview");
        let primaryAction = `<button disabled>${escapeHtml(t("manualReview"))}</button>`;
        if (lead.partner_status === "verification_pending") {
          lifecycleText = t("registrationReported");
          primaryAction = `<button class="primary-mini" data-action="mark-joined" data-email="${escapeHtml(lead.email)}">${escapeHtml(t("markJoined"))}</button>`;
        } else if (lead.partner_status === "joined" && !lead.partner) {
          lifecycleText = t("lifecycleJoined");
          primaryAction = `<button class="primary-mini" data-action="assign-partner" data-email="${escapeHtml(lead.email)}">${escapeHtml(t("assignPartner"))}</button>`;
        } else if (lead.partner?.status === "assigned") {
          lifecycleText = t("assignedCode");
          primaryAction = `<button class="primary-mini" data-action="send-partner" data-email="${escapeHtml(lead.email)}">${escapeHtml(t("sendPartnerCode"))}</button>`;
        } else if (lead.partner_status === "code_sent") {
          lifecycleText = t("partnerEmailSent", { date: formatDate(lead.partner?.sent_at) });
          primaryAction = `<button disabled>${escapeHtml(t("sentComplete"))}</button>`;
        }
        return `<article class="reply-card">
          <div class="reply-card-head">
            <span class="creator-avatar">${escapeHtml(initial)}</span>
            <span class="creator-identity"><strong>${escapeHtml(name)}</strong><small>${escapeHtml(lead.handle)} · ${escapeHtml(lead.email)}</small></span>
            <span class="status-pill replied">${escapeHtml(t("replied"))}</span>
          </div>
          <div class="reply-meta"><span>${escapeHtml(lead.source_keyword || "Creator")}</span><span>${escapeHtml(lifecycleText)}</span><span>${escapeHtml(lead.reply_intent || "replied")}</span></div>
          <div class="reply-actions">
            <button data-action="research" data-email="${escapeHtml(lead.email)}">${escapeHtml(t("viewProfile"))}</button>
            ${primaryAction}
          </div>
        </article>`;
      }).join("")
    : `<div class="empty-job"><span>✉</span><p>${escapeHtml(t("noRepliesOne"))}<br>${escapeHtml(t("noRepliesTwo"))}</p></div>`;
}

function renderJob(job) {
  state.activeJob = job?.status === "running" ? job : null;
  const empty = $("#emptyJob");
  const consoleView = $("#jobConsole");
  if (!job) {
    empty.classList.remove("hidden");
    consoleView.classList.add("hidden");
    $("#jobStatus").textContent = t("noTask");
    $("#jobStatus").className = "job-status idle";
    return;
  }
  empty.classList.add("hidden");
  consoleView.classList.remove("hidden");
  $("#jobTitle").textContent = displayJobLabel(job.label);
  $("#jobLogs").textContent = job.logs?.length ? job.logs.join("\n") : t("taskWaiting");
  $("#jobLogs").scrollTop = $("#jobLogs").scrollHeight;
  const labels = { running: t("running"), completed: t("completed"), failed: t("stopped") };
  $("#jobStatus").textContent = labels[job.status] || job.status;
  $("#jobStatus").className = `job-status ${job.status}`;
}

async function loadStatus({ quiet = false } = {}) {
  try {
    state.data = await api("/api/status");
    if (state.data.activeJob) state.activeJob = state.data.activeJob;
    renderStats();
    renderContacts();
    renderReplies();
    if (state.data.activeJob) {
      renderJob(state.data.activeJob);
      pollJob(state.data.activeJob.id);
    } else if (!state.activeJob) {
      renderJob(null);
    }
  } catch (error) {
    if (!quiet) toast(error.message, "error");
  }
}

async function previewCampaign() {
  const button = $("#previewCampaignButton");
  setBusy(button, true);
  try {
    state.plan = await api("/api/campaign/preview", {
      method: "POST",
      body: JSON.stringify(campaignInput()),
    });
    renderPlanPreview();
  } catch (error) {
    toast(error.message, "error");
  } finally {
    setBusy(button, false);
  }
}

function renderPlanPreview() {
  if (!state.plan) return;
  $("#costBadge").textContent = t("maxCost", { amount: state.plan.estimatedFee.toFixed(2) });
  const rules = [t("ruleDirect"), t("ruleExclude"), t("ruleNoAutoSend")];
  $("#planPreview").innerHTML = `<strong>${escapeHtml(t("planReady"))}</strong><br>${state.plan.input.keywords.map(escapeHtml).join(" · ")} · ${escapeHtml(t("maxResultsPlan", { count: state.plan.maxEmails }))}<br>${rules.map((rule) => `✓ ${escapeHtml(rule)}`).join("<br>")}`;
  $("#planPreview").classList.remove("hidden");
}

function campaignInput() {
  return {
    keywords: $("#keywordInput").value,
    maxEmails: Number($("#maxEmailsInput").value),
    location: $("#locationInput").value,
  };
}

function openModal({ kicker = "CONFIRM ACTION", title, description, content, confirmText = t("confirm"), onConfirm }) {
  $("#modalKicker").textContent = kicker;
  $("#modalTitle").textContent = title;
  $("#modalDescription").innerHTML = description;
  $("#modalContent").innerHTML = content || "";
  $("#modalConfirm").textContent = confirmText;
  state.modalAction = onConfirm;
  $("#modalBackdrop").classList.remove("hidden");
  setTimeout(() => $("#modalContent input")?.focus(), 60);
}

function closeModal() {
  $("#modalBackdrop").classList.add("hidden");
  state.modalAction = null;
}

async function startJob(path, payload) {
  const job = await api(path, { method: "POST", body: JSON.stringify(payload) });
  closeModal();
  renderJob(job);
  state.activeJob = job;
  renderStats();
  toast(t("jobStarted", { label: displayJobLabel(job.label) }));
  pollJob(job.id);
}

let pollingJobId = "";
async function pollJob(id) {
  if (pollingJobId === id) return;
  pollingJobId = id;
  while (pollingJobId === id) {
    try {
      const job = await api(`/api/jobs/${id}`);
      renderJob(job);
      if (job.status !== "running") {
        pollingJobId = "";
        state.activeJob = null;
        toast(job.status === "completed"
          ? t("jobCompleted", { label: displayJobLabel(job.label) })
          : t("jobStopped", { label: displayJobLabel(job.label) }), job.status === "completed" ? "success" : "error");
        await loadStatus({ quiet: true });
        break;
      }
    } catch (error) {
      pollingJobId = "";
      toast(error.message, "error");
      break;
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
}

function runCampaign() {
  const maxEmails = Number($("#maxEmailsInput").value) || 50;
  if (!$("#keywordInput").value.trim()) return toast(t("enterKeywords"), "error");
  const phrase = `RUN ${maxEmails}`;
  openModal({
    kicker: "PAID DISCOVERY",
    title: t("paidDiscoveryTitle"),
    description: t("paidDiscoveryDescription", { count: maxEmails, amount: (maxEmails * .0025).toFixed(2) }),
    content: confirmInput(t("enterPhrase", { phrase }), "campaign-confirm"),
    confirmText: t("beginScrape"),
    onConfirm: () => startJob("/api/campaign/run", { ...campaignInput(), confirmation: $("#campaign-confirm").value }),
  });
}

function confirmInput(label, id, extra = "") {
  return `<label class="confirm-field"><span>${escapeHtml(label)}</span><input id="${escapeHtml(id)}" type="text" autocomplete="off"></label>${extra}`;
}

function approveLeads() {
  const count = state.data.summary.pending;
  const phrase = `APPROVE ${count}`;
  openModal({
    title: t("approveTitle", { count }),
    description: t("approveDescription"),
    content: confirmInput(t("enterPhrase", { phrase }), "approve-confirm"),
    confirmText: t("approveConfirm"),
    onConfirm: () => startJob("/api/approve", { confirmation: $("#approve-confirm").value }),
  });
}

function sendEmails() {
  const count = state.data.summary.eligible;
  const phrase = `SEND ${count}`;
  const resumeField = state.data.paused
    ? confirmInput(t("resumePrompt"), "resume-confirm")
    : "";
  openModal({
    kicker: "LIVE EMAIL SEND",
    title: t("monitoredSendTitle", { count }),
    description: t("sendDescription"),
    content: confirmInput(t("enterPhrase", { phrase }), "send-confirm", resumeField),
    confirmText: t("beginSend"),
    onConfirm: () => startJob("/api/send", {
      confirmation: $("#send-confirm").value,
      resumeConfirmation: $("#resume-confirm")?.value || "",
    }),
  });
}

async function syncInbox() {
  if (state.activeJob) return toast(t("waitForTask"), "error");
  try {
    await startJob("/api/sync", {});
  } catch (error) {
    toast(error.message, "error");
  }
}

function openDrawer(title, html) {
  $("#drawerTitle").textContent = title;
  $("#drawerContent").innerHTML = html;
  $("#drawerBackdrop").classList.remove("hidden");
  $("#drawer").classList.add("open");
  $("#drawer").setAttribute("aria-hidden", "false");
}

function closeDrawer() {
  $("#drawerBackdrop").classList.add("hidden");
  $("#drawer").classList.remove("open");
  $("#drawer").setAttribute("aria-hidden", "true");
}

async function showTemplate() {
  try {
    const template = await api("/api/template");
    openDrawer(t("firstEmailTitle"), `<div class="email-preview"><div class="subject"><strong>Subject:</strong> ${escapeHtml(template.subject)}</div><pre>${escapeHtml(template.body)}</pre></div>`);
  } catch (error) {
    toast(error.message, "error");
  }
}

function assignCode(email) {
  const lead = state.data.replies.find((item) => item.email === email);
  const phrase = `ASSIGN ${email}`;
  openModal({
    kicker: "APPLE OFFER CODE",
    title: t("assignPartner"),
    description: t("assignDescription", { handle: escapeHtml(lead.handle) }),
    content: `${confirmInput(t("creatorName"), "creator-name")}${confirmInput(t("enterPhrase", { phrase }), "assign-confirm")}`,
    confirmText: t("assignCode"),
    onConfirm: () => startJob("/api/partner/assign", {
      email,
      name: $("#creator-name").value,
      confirmation: $("#assign-confirm").value,
    }),
  });
}

function markPartnerJoined(email) {
  const phrase = `MARK PARTNER JOINED ${email}`;
  openModal({
    kicker: "AFFILIATE VERIFIED",
    title: t("markJoined"),
    description: t("joinDescription"),
    content: `${confirmInput(t("affiliateLink"), "affiliate-link")}${confirmInput(t("enterPhrase", { phrase }), "joined-confirm")}`,
    confirmText: t("markJoined"),
    onConfirm: () => startJob("/api/partner/joined", {
      email,
      affiliateLink: $("#affiliate-link").value,
      confirmation: $("#joined-confirm").value,
    }),
  });
}

function sendPartnerEmail(email) {
  const phrase = `SEND PARTNER CODE ${email}`;
  openModal({
    kicker: "PARTNER EMAIL",
    title: t("sendCodeAffiliate"),
    description: t("partnerCodeDescription"),
    content: confirmInput(t("enterPhrase", { phrase }), "partner-confirm"),
    confirmText: t("sendPartnerEmail"),
    onConfirm: () => startJob("/api/partner/send", {
      email,
      confirmation: $("#partner-confirm").value,
    }),
  });
}

async function researchCreator(email) {
  openDrawer(t("publicProfile"), `<div class="empty-job"><span>⌁</span><p>${escapeHtml(t("readingProfile"))}</p></div>`);
  try {
    const result = await api("/api/research", { method: "POST", body: JSON.stringify({ email }) });
    $("#drawerContent").innerHTML = `
      <div class="email-preview">
        <div class="subject"><strong>${escapeHtml(result.nickname || result.handle)}</strong><br><a class="source-link" href="${escapeHtml(result.profileUrl)}" target="_blank" rel="noreferrer">${escapeHtml(result.handle)} ↗</a></div>
        <div class="research-grid">
          <div><span>${escapeHtml(t("followers"))}</span><strong>${compactNumber(result.followers)}</strong></div>
          <div><span>${escapeHtml(t("totalLikes"))}</span><strong>${compactNumber(result.likes)}</strong></div>
          <div><span>${escapeHtml(t("videos"))}</span><strong>${compactNumber(result.videos)}</strong></div>
          <div><span>${escapeHtml(t("region"))}</span><strong>${escapeHtml(result.region || "—")}</strong></div>
        </div>
        <div class="research-bio">${escapeHtml(result.signature || t("noPublicBio"))}</div>
      </div>`;
  } catch (error) {
    $("#drawerContent").innerHTML = `<div class="research-bio">${escapeHtml(error.message)}</div>`;
  }
}

$$('[data-keyword]').forEach((button) => {
  button.addEventListener("click", () => {
    const current = $("#keywordInput").value.trim();
    if (!current.includes(button.dataset.keyword)) {
      $("#keywordInput").value = [current, button.dataset.keyword].filter(Boolean).join("\n");
    }
  });
});

$("#maxEmailsInput").addEventListener("input", (event) => {
  const count = Math.max(1, Math.min(105, Number(event.target.value) || 50));
  $("#costBadge").textContent = t("maxCost", { amount: (count * .0025).toFixed(2) });
  state.plan = null;
});
$$('[data-language]').forEach((button) => {
  button.addEventListener("click", () => {
    closeModal();
    closeDrawer();
    state.language = button.dataset.language;
    applyLanguage();
  });
});
$("#previewCampaignButton").addEventListener("click", previewCampaign);
$("#runCampaignButton").addEventListener("click", runCampaign);
$("#approveButton").addEventListener("click", approveLeads);
$("#sendButton").addEventListener("click", sendEmails);
$("#syncButton").addEventListener("click", syncInbox);
$("#templateButton").addEventListener("click", showTemplate);
$("#refreshButton").addEventListener("click", () => loadStatus());
$("#contactSearch").addEventListener("input", renderContacts);
$("#statusFilter").addEventListener("change", renderContacts);
$("#showMoreButton").addEventListener("click", () => { state.tableLimit += 24; renderContacts(); });
$("#modalClose").addEventListener("click", closeModal);
$("#modalCancel").addEventListener("click", closeModal);
$("#modalBackdrop").addEventListener("click", (event) => { if (event.target === $("#modalBackdrop")) closeModal(); });
$("#modalConfirm").addEventListener("click", async () => {
  if (!state.modalAction) return;
  const button = $("#modalConfirm");
  setBusy(button, true);
  try {
    await state.modalAction();
  } catch (error) {
    toast(error.message, "error");
  } finally {
    setBusy(button, false);
  }
});
$("#drawerClose").addEventListener("click", closeDrawer);
$("#drawerBackdrop").addEventListener("click", closeDrawer);
$("#replyGrid").addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const { action, email } = button.dataset;
  if (action === "mark-joined") markPartnerJoined(email);
  if (action === "assign-partner") assignCode(email);
  if (action === "send-partner") sendPartnerEmail(email);
  if (action === "research") researchCreator(email);
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") { closeModal(); closeDrawer(); }
});

applyLanguage();
loadStatus();
setInterval(() => { if (!state.activeJob) loadStatus({ quiet: true }); }, 30_000);
