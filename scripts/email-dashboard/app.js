const root = location.pathname.replace(/\/$/, "");
const byId = (id) => document.getElementById(id);
const labels = {
  trial_ending_48h: "试用结束前 48 小时",
  trial_ending_24h: "试用结束前 24 小时（已停用）",
  trial_cancelled_winback: "取消试用召回",
  billing_issue: "付款失败提醒",
  marketing_winback_1: "未活跃召回 · 第 1 封",
  marketing_winback_2: "未活跃召回 · 第 2 封",
  marketing_winback_3: "未活跃召回 · 第 3 封"
};
const controls = { days: byId("days"), kind: byId("kind"), state: byId("state"), search: byId("search") };
let page = 1;
let current = null;
let busy = false;
let reloadQueued = false;
let searchTimer = null;

function text(tag, value, className = "") {
  const element = document.createElement(tag);
  element.textContent = value == null || value === "" ? "—" : String(value);
  if (className) element.className = className;
  return element;
}

function count(groups, predicate) {
  return groups.filter(predicate).reduce((sum, group) => sum + group.count, 0);
}

function stateOf(row) {
  if (row.providerStatus === "delivered") return ["已送达", "delivered"];
  if (row.providerStatus === "bounced") return ["退信", "bounced"];
  if (row.providerStatus === "complained") return ["被投诉", "complained"];
  if (row.providerStatus === "rejected") return ["被拒绝", "rejected"];
  if (row.status === "sent") return [row.providerStatus === "delayed" ? "投递延迟" : "已发送", "accepted"];
  const other = { scheduled: "待发送", processing: "处理中", failed: "失败", skipped: "已跳过", cancelled: "已取消", suppressed: "已抑制" };
  return [other[row.status] || row.status, row.status];
}

function localTime(value) {
  return value ? new Intl.DateTimeFormat("zh-CN", { timeZone: "Asia/Shanghai", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(value)) : "—";
}

function render(data) {
  current = data;
  const groups = data.groups;
  const sent = count(groups, (group) => group.status === "sent");
  const delivered = count(groups, (group) => group.providerStatus === "delivered");
  const bounced = count(groups, (group) => group.providerStatus === "bounced");
  const scheduled = count(groups, (group) => group.status === "scheduled" || group.status === "processing");
  const failed = count(groups, (group) => group.status === "failed" || group.status === "skipped");
  for (const [id, value] of Object.entries({ sent, delivered, bounced, scheduled, failed })) byId(id).textContent = value.toLocaleString("zh-CN");
  byId("updated").textContent = `更新于 ${localTime(data.fetchedAt)}`;

  const byKind = new Map();
  for (const group of groups) byKind.set(group.kind, (byKind.get(group.kind) || 0) + group.count);
  const kinds = byId("kinds");
  kinds.replaceChildren();
  for (const [kind, total] of [...byKind].sort((a, b) => b[1] - a[1])) {
    const item = document.createElement("div");
    item.className = "kind";
    item.append(text("span", labels[kind] || kind), text("strong", total.toLocaleString("zh-CN")));
    kinds.append(item);
  }
  if (!byKind.size) kinds.append(text("p", "这个时间范围还没有邮件记录。", "muted"));
  const oldKind = controls.kind.value;
  controls.kind.replaceChildren(new Option("全部类型", ""));
  for (const kind of byKind.keys()) controls.kind.add(new Option(labels[kind] || kind, kind));
  controls.kind.value = oldKind;

  const body = byId("rows");
  body.replaceChildren();
  for (const row of data.deliveries) {
    const tr = document.createElement("tr");
    const [status, className] = stateOf(row);
    const statusCell = document.createElement("td");
    statusCell.append(text("span", status, `pill ${className}`));
    tr.append(
      text("td", row.email || "邮箱不可用"),
      text("td", labels[row.kind] || row.kind),
      statusCell,
      text("td", localTime(row.sentAt || row.scheduledAt || row.createdAt)),
      text("td", row.lastError)
    );
    body.append(tr);
  }
  if (!data.deliveries.length) {
    const tr = document.createElement("tr");
    const td = text("td", "没有符合筛选条件的邮件。", "empty");
    td.colSpan = 5;
    tr.append(td);
    body.append(tr);
  }
  const first = data.count ? (page - 1) * data.pageSize + 1 : 0;
  const last = Math.min(page * data.pageSize, data.count);
  byId("result-count").textContent = `${data.count.toLocaleString("zh-CN")} 条记录`;
  byId("page-info").textContent = `第 ${first}–${last} 条，共 ${data.count.toLocaleString("zh-CN")} 条`;
  byId("previous").disabled = page <= 1;
  byId("next").disabled = page * data.pageSize >= data.count;
}

async function load() {
  if (busy) { reloadQueued = true; return; }
  busy = true;
  byId("refresh").disabled = true;
  byId("error").hidden = true;
  const params = new URLSearchParams({ days: controls.days.value, kind: controls.kind.value, state: controls.state.value, search: controls.search.value.trim(), page: String(page) });
  try {
    const response = await fetch(`${root}/api/data?${params}`, { cache: "no-store" });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || "读取邮件数据失败");
    render(data);
  } catch (error) {
    byId("error").textContent = `暂时无法读取数据：${error.message}`;
    byId("error").hidden = false;
    if (!current) byId("updated").textContent = "连接失败";
  } finally {
    busy = false;
    byId("refresh").disabled = false;
    if (reloadQueued) {
      reloadQueued = false;
      load();
    }
  }
}

controls.days.addEventListener("change", () => { page = 1; controls.kind.value = ""; load(); });
controls.kind.addEventListener("change", () => { page = 1; load(); });
controls.state.addEventListener("change", () => { page = 1; load(); });
controls.search.addEventListener("input", () => { clearTimeout(searchTimer); searchTimer = setTimeout(() => { page = 1; load(); }, 350); });
byId("refresh").addEventListener("click", load);
byId("previous").addEventListener("click", () => { page--; load(); });
byId("next").addEventListener("click", () => { page++; load(); });
if (location.protocol === "file:") {
  byId("updated").textContent = "打开方式不正确";
  byId("error").textContent = "请不要直接打开 index.html。请在 Finder 中双击项目根目录的「打开邮件看板.command」，它会自动启动并打开可读取数据的看板。";
  byId("error").hidden = false;
  byId("refresh").disabled = true;
  byId("rows").replaceChildren();
  const row = document.createElement("tr");
  const cell = text("td", "请先使用「打开邮件看板.command」启动。", "empty");
  cell.colSpan = 5;
  row.append(cell);
  byId("rows").append(row);
} else {
  load();
}
