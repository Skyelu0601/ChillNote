"use client";

import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import {
  BarChart3,
  Bot,
  Check,
  CheckSquare,
  CreditCard,
  ExternalLink,
  FileText,
  Link2,
  Loader2,
  LogOut,
  Mic,
  Pin,
  PinOff,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  Settings as SettingsIcon,
  Sparkles,
  Square,
  Tag,
  Trash2,
  X,
} from "lucide-react";
import type { Session } from "@supabase/supabase-js";
import { copy } from "@/lib/copy";
import {
  checkDailyQuota,
  createCreemCheckout,
  getSubscriptionStatus,
  makeEmptyNote,
  makeTag,
  NoteDTO,
  prepareNoteForSave,
  prepareTagForSave,
  refineVoiceTranscript,
  runAgentRecipe,
  SubscriptionStatus,
  syncNotes,
  TagDTO,
  tidyNote,
  transcribeAudio,
} from "@/lib/chillnote-api";
import {
  activeTagsForNote,
  autoColorHex,
  daysRemainingInTrash,
  FREE_RECORDING_TIME_LIMIT_SECONDS,
  dateTimeOrNull,
  getOrCreateDeviceId,
  metadataFromURL,
  normalizeTagColorHex,
  parseChecklist,
  previewPlainText,
  PRO_RECORDING_TIME_LIMIT_SECONDS,
  sortNotesForFeed,
  sourceMetadataForNote,
  toggleChecklistItem,
} from "@/lib/chillnote-model";
import {
  agentRecipes,
  buildAgentRecipeRequest,
  defaultSavedRecipeIds,
  recipeCategoryLabels,
  type AgentRecipeCategory,
} from "@/lib/agent-recipes";
import { supabase } from "@/lib/supabase";
import { AuthPanel } from "./auth-panel";

type FeedMode = "active" | "trash";
type MainPanel = "notes" | "stats" | "skills" | "settings";
type RecipeScope = "active" | "visible";
type VoiceLanguageMode = "auto" | "prefer";

const WEB_SAVED_RECIPE_IDS_KEY = "chillnote.web.saved_recipe_ids";
const WEB_VOICE_LANGUAGE_MODE_KEY = "chillnote.web.voice_language_mode";
const WEB_VOICE_LANGUAGE_HINT_KEY = "chillnote.web.voice_language_hint";

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function renderInlineMarkdown(value: string) {
  const escaped = escapeHtml(value);
  return escaped
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*]+)\*/g, "<em>$1</em>");
}

function markdownToEditorHtml(markdown: string) {
  if (!markdown.trim()) return "";
  const lines = markdown.split("\n");
  const blocks: string[] = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index];
    const trimmed = line.trim();

    if (!trimmed) {
      blocks.push("<p><br></p>");
      index += 1;
      continue;
    }

    if (/^---+$/.test(trimmed)) {
      blocks.push("<hr>");
      index += 1;
      continue;
    }

    const headingMatch = /^(#{1,6})\s+(.+)$/.exec(line);
    if (headingMatch) {
      const level = headingMatch[1].length;
      blocks.push(`<h${level}>${renderInlineMarkdown(headingMatch[2])}</h${level}>`);
      index += 1;
      continue;
    }

    if (trimmed.startsWith("> ")) {
      blocks.push(`<blockquote>${renderInlineMarkdown(trimmed.slice(2))}</blockquote>`);
      index += 1;
      continue;
    }

    if (/^[-*]\s+(\[[ xX]\]\s*)?/.test(trimmed)) {
      const items: string[] = [];
      while (index < lines.length) {
        const itemMatch = /^[-*]\s+(?:\[([ xX])\]\s*)?(.*)$/.exec(lines[index].trim());
        if (!itemMatch) break;
        const checked = itemMatch[1]?.toLowerCase() === "x";
        const content = renderInlineMarkdown(itemMatch[2]);
        if (itemMatch[1]) {
          items.push(`<li data-task="true" data-checked="${checked ? "true" : "false"}"><span class="task-box">${checked ? "✓" : ""}</span>${content || "&nbsp;"}</li>`);
        } else {
          items.push(`<li>${content || "&nbsp;"}</li>`);
        }
        index += 1;
      }
      blocks.push(`<ul>${items.join("")}</ul>`);
      continue;
    }

    blocks.push(`<p>${renderInlineMarkdown(line)}</p>`);
    index += 1;
  }

  return blocks.join("");
}

function inlineNodeToMarkdown(node: Node): string {
  if (node.nodeType === Node.TEXT_NODE) return node.textContent ?? "";
  if (!(node instanceof HTMLElement)) return "";

  const content = Array.from(node.childNodes).map(inlineNodeToMarkdown).join("");
  if (node.matches(".task-box")) return "";
  if (node.tagName === "STRONG" || node.tagName === "B") return `**${content}**`;
  if (node.tagName === "EM" || node.tagName === "I") return `*${content}*`;
  if (node.tagName === "CODE") return `\`${content}\``;
  if (node.tagName === "BR") return "\n";
  return content;
}

function editorHtmlToMarkdown(root: HTMLElement) {
  const lines: string[] = [];

  for (const child of Array.from(root.childNodes)) {
    if (child.nodeType === Node.TEXT_NODE) {
      const text = child.textContent ?? "";
      if (text.trim()) lines.push(text);
      continue;
    }
    if (!(child instanceof HTMLElement)) continue;

    const tagName = child.tagName;
    const text = Array.from(child.childNodes).map(inlineNodeToMarkdown).join("").replace(/\u00a0/g, " ").trimEnd();

    if (/^H[1-6]$/.test(tagName)) {
      lines.push(`${"#".repeat(Number(tagName.slice(1)))} ${text.trim()}`);
    } else if (tagName === "BLOCKQUOTE") {
      lines.push(`> ${text.trim()}`);
    } else if (tagName === "UL" || tagName === "OL") {
      for (const item of Array.from(child.children)) {
        if (!(item instanceof HTMLElement) || item.tagName !== "LI") continue;
        const itemText = Array.from(item.childNodes).map(inlineNodeToMarkdown).join("").replace(/\u00a0/g, " ").trim();
        if (item.dataset.task === "true") {
          lines.push(`- [${item.dataset.checked === "true" ? "x" : " "}] ${itemText}`.trimEnd());
        } else {
          lines.push(`- ${itemText}`.trimEnd());
        }
      }
    } else if (tagName === "HR") {
      lines.push("---");
    } else {
      lines.push(text.trim() ? text : "");
    }
  }

  return lines.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

function MarkdownRichEditor({
  value,
  onChange,
  placeholder,
  disabled,
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  disabled: boolean;
}) {
  const editorRef = useRef<HTMLDivElement | null>(null);
  const lastMarkdownRef = useRef<string | null>(null);

  useLayoutEffect(() => {
    const editor = editorRef.current;
    if (!editor || value === lastMarkdownRef.current) return;
    if (document.activeElement === editor) return;
    editor.innerHTML = markdownToEditorHtml(value);
    lastMarkdownRef.current = value;
  }, [value]);

  function handleInput() {
    const editor = editorRef.current;
    if (!editor) return;
    const nextValue = editorHtmlToMarkdown(editor);
    lastMarkdownRef.current = nextValue;
    onChange(nextValue);
  }

  return (
    <div
      ref={editorRef}
      className="rich-note-editor"
      contentEditable={!disabled}
      data-placeholder={placeholder}
      onInput={handleInput}
      role="textbox"
      aria-multiline="true"
      spellCheck
      suppressContentEditableWarning
    />
  );
}

function formatDate(value?: string | null) {
  if (!value) return copy.app.neverSynced;
  const time = dateTimeOrNull(value);
  if (time == null) return copy.app.neverSynced;
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(time));
}

function blobToBase64(blob: Blob) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const result = String(reader.result ?? "");
      resolve(result.includes(",") ? result.split(",")[1] : result);
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

function loadStringArray(key: string, fallback: string[]) {
  if (typeof window === "undefined") return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return fallback;
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === "string") : fallback;
  } catch {
    return fallback;
  }
}

function saveStringArray(key: string, value: string[]) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(key, JSON.stringify(value));
}

function startOfToday() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
}

function startOfCurrentWeek() {
  const today = new Date(startOfToday());
  const day = today.getDay();
  const mondayOffset = day === 0 ? -6 : 1 - day;
  today.setDate(today.getDate() + mondayOffset);
  return today.getTime();
}

function mergeNotes(current: NoteDTO[], incoming: NoteDTO[], hardDeletedIds: string[] = []) {
  const byId = new Map(current.map((note) => [note.id, note]));
  for (const note of incoming) byId.set(note.id, note);
  for (const id of hardDeletedIds) byId.delete(id);
  return Array.from(byId.values());
}

function mergeTags(current: TagDTO[], incoming: TagDTO[], hardDeletedIds: string[] = []) {
  const byId = new Map(current.map((tag) => [tag.id, tag]));
  for (const tag of incoming) byId.set(tag.id, tag);
  for (const id of hardDeletedIds) byId.delete(id);
  return Array.from(byId.values());
}

export function ChillNoteWebApp() {
  const [session, setSession] = useState<Session | null>(null);
  const [authReady, setAuthReady] = useState(false);
  const [notes, setNotes] = useState<NoteDTO[]>([]);
  const [tags, setTags] = useState<TagDTO[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [query, setQuery] = useState("");
  const [feedMode, setFeedMode] = useState<FeedMode>("active");
  const [selectedTagId, setSelectedTagId] = useState<string | null>(null);
  const [subscription, setSubscription] = useState<SubscriptionStatus | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [syncing, setSyncing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [tidying, setTidying] = useState(false);
  const [recording, setRecording] = useState(false);
  const [transcribing, setTranscribing] = useState(false);
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [newTagName, setNewTagName] = useState("");
  const [sourceURLDraft, setSourceURLDraft] = useState("");
  const [mainPanel, setMainPanel] = useState<MainPanel>("notes");
  const [savedRecipeIds, setSavedRecipeIds] = useState<string[]>(defaultSavedRecipeIds);
  const [selectedRecipeId, setSelectedRecipeId] = useState(defaultSavedRecipeIds[0]);
  const [selectedRecipeCategory, setSelectedRecipeCategory] = useState<AgentRecipeCategory>("think");
  const [recipeScope, setRecipeScope] = useState<RecipeScope>("active");
  const [recipeInstruction, setRecipeInstruction] = useState("English");
  const [runningRecipe, setRunningRecipe] = useState(false);
  const [voiceLanguageMode, setVoiceLanguageMode] = useState<VoiceLanguageMode>("auto");
  const [voiceLanguageHint, setVoiceLanguageHint] = useState("");
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const deviceIdRef = useRef<string | null>(null);
  const recordingTimeoutRef = useRef<number | null>(null);
  const stoppingRecordingRef = useRef(false);

  useEffect(() => {
    deviceIdRef.current = getOrCreateDeviceId();
    setSavedRecipeIds(loadStringArray(WEB_SAVED_RECIPE_IDS_KEY, defaultSavedRecipeIds));
    const storedMode = window.localStorage.getItem(WEB_VOICE_LANGUAGE_MODE_KEY);
    setVoiceLanguageMode(storedMode === "prefer" ? "prefer" : "auto");
    setVoiceLanguageHint(window.localStorage.getItem(WEB_VOICE_LANGUAGE_HINT_KEY) ?? "");
  }, []);

  useEffect(() => {
    saveStringArray(WEB_SAVED_RECIPE_IDS_KEY, savedRecipeIds);
  }, [savedRecipeIds]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(WEB_VOICE_LANGUAGE_MODE_KEY, voiceLanguageMode);
    window.localStorage.setItem(WEB_VOICE_LANGUAGE_HINT_KEY, voiceLanguageHint);
  }, [voiceLanguageMode, voiceLanguageHint]);

  const activeNote = notes.find((note) => note.id === activeId) ?? null;
  const activeTags = activeTagsForNote(activeNote, tags);
  const sourceMetadata = sourceMetadataForNote(activeNote);
  const checklist = parseChecklist(draft);
  const isPro = subscription?.tier === "pro";
  const recordingLimit = isPro ? PRO_RECORDING_TIME_LIMIT_SECONDS : FREE_RECORDING_TIME_LIMIT_SECONDS;

  const visibleTags = useMemo(() => {
    return [...tags]
      .filter((tag) => !tag.deletedAt)
      .sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name));
  }, [tags]);

  const visibleNotes = useMemo(() => {
    const cleanQuery = query.trim().toLowerCase();
    const filtered = notes.filter((note) => {
      if (feedMode === "active" && note.deletedAt) return false;
      if (feedMode === "trash" && !note.deletedAt) return false;
      if (selectedTagId && !(note.tagIds ?? []).includes(selectedTagId)) return false;

      if (!cleanQuery) return true;
      const noteTags = activeTagsForNote(note, tags).map((tag) => tag.name.toLowerCase());
      return previewPlainText(note.content).toLowerCase().includes(cleanQuery)
        || noteTags.some((tagName) => tagName.includes(cleanQuery));
    });
    return sortNotesForFeed(filtered);
  }, [feedMode, notes, query, selectedTagId, tags]);

  const activeNotes = useMemo(() => notes.filter((note) => !note.deletedAt), [notes]);
  const notesStats = useMemo(() => {
    const todayStart = startOfToday();
    const weekStart = startOfCurrentWeek();
    return {
      totalNotes: activeNotes.length,
      totalTags: visibleTags.length,
      todayNew: activeNotes.filter((note) => (dateTimeOrNull(note.createdAt) ?? 0) >= todayStart).length,
      weekNew: activeNotes.filter((note) => (dateTimeOrNull(note.createdAt) ?? 0) >= weekStart).length,
    };
  }, [activeNotes, visibleTags.length]);

  const libraryRecipes = useMemo(
    () => agentRecipes.filter((recipe) => recipe.category === selectedRecipeCategory),
    [selectedRecipeCategory]
  );
  const savedRecipes = useMemo(
    () => savedRecipeIds
      .map((id) => agentRecipes.find((recipe) => recipe.id === id))
      .filter((recipe): recipe is (typeof agentRecipes)[number] => Boolean(recipe)),
    [savedRecipeIds]
  );
  const selectedRecipe = agentRecipes.find((recipe) => recipe.id === selectedRecipeId)
    ?? savedRecipes[0]
    ?? agentRecipes[0];

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setAuthReady(true);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setAuthReady(true);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) return;
    void refreshAll(null);
  }, [session]);

  useEffect(() => {
    setDraft(activeNote?.content ?? "");
    setSourceURLDraft(activeNote?.sourceURL ?? "");
  }, [activeNote?.id]);

  useEffect(() => {
    if (activeId && visibleNotes.some((note) => note.id === activeId)) return;
    setActiveId(visibleNotes[0]?.id ?? null);
  }, [activeId, visibleNotes]);

  async function refreshAll(nextCursor = cursor) {
    if (!session) return;
    setSyncing(true);
    setError(null);
    try {
      const [syncResponse, subResponse] = await Promise.all([
        syncNotes(session.access_token, {
          cursor: nextCursor,
          deviceId: deviceIdRef.current,
          notes: [],
          tags: [],
        }),
        getSubscriptionStatus(session.access_token),
      ]);
      setCursor(syncResponse.cursor);
      setSubscription(subResponse);
      setStatus(syncResponse.serverTime);
      setNotes((current) => mergeNotes(
        current,
        syncResponse.changes.notes,
        syncResponse.changes.hardDeletedNoteIds ?? []
      ));
      setTags((current) => mergeTags(
        current,
        syncResponse.changes.tags ?? [],
        syncResponse.changes.hardDeletedTagIds ?? []
      ));
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      setSyncing(false);
    }
  }

  function createNote(initialContent = "") {
    if (!session?.user.id) return;
    const note = makeEmptyNote(session.user.id);
    note.content = initialContent;
    setFeedMode("active");
    setNotes((current) => [note, ...current]);
    setActiveId(note.id);
    setDraft(initialContent);
  }

  async function pushChanges(payload: { notes?: NoteDTO[]; tags?: TagDTO[]; hardDeletedNoteIds?: string[]; hardDeletedTagIds?: string[] }) {
    if (!session) return null;
    const response = await syncNotes(session.access_token, {
      cursor,
      deviceId: deviceIdRef.current,
      notes: payload.notes ?? [],
      tags: payload.tags ?? [],
      hardDeletedNoteIds: payload.hardDeletedNoteIds,
      hardDeletedTagIds: payload.hardDeletedTagIds,
    });
    setCursor(response.cursor);
    setStatus(response.serverTime);
    setNotes((current) => mergeNotes(current, response.changes.notes, response.changes.hardDeletedNoteIds ?? []));
    setTags((current) => mergeTags(current, response.changes.tags ?? [], response.changes.hardDeletedTagIds ?? []));
    return response;
  }

  async function saveDraft(nextContent = draft, patch: Partial<NoteDTO> = {}) {
    if (!session || !activeNote) return null;
    if (!nextContent.trim()) {
      setError(copy.errors.emptyNote);
      return null;
    }
    setSaving(true);
    setError(null);
    try {
      const noteToSave = prepareNoteForSave({ ...activeNote, ...patch, content: nextContent });
      setNotes((current) => current.map((note) => (note.id === noteToSave.id ? noteToSave : note)));
      const response = await pushChanges({ notes: [noteToSave] });
      return response;
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
      return null;
    } finally {
      setSaving(false);
    }
  }

  async function softDeleteActiveNote() {
    if (!activeNote) return;
    const now = new Date().toISOString();
    await saveDraft(activeNote.content || " ", { deletedAt: now });
    setFeedMode("active");
  }

  async function restoreActiveNote() {
    if (!activeNote) return;
    await saveDraft(activeNote.content || " ", { deletedAt: null });
    setFeedMode("active");
  }

  async function hardDeleteActiveNote() {
    if (!session || !activeNote) return;
    setSaving(true);
    setError(null);
    try {
      const id = activeNote.id;
      setNotes((current) => current.filter((note) => note.id !== id));
      setActiveId(visibleNotes.find((note) => note.id !== id)?.id ?? null);
      await pushChanges({ hardDeletedNoteIds: [id] });
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      setSaving(false);
    }
  }

  async function togglePin() {
    if (!activeNote) return;
    const pinnedAt = activeNote.pinnedAt ? null : new Date().toISOString();
    await saveDraft(draft, { pinnedAt });
  }

  async function tidyDraft() {
    if (!session || !draft.trim()) {
      setError(copy.errors.emptyNote);
      return;
    }
    setTidying(true);
    setError(null);
    try {
      const tidied = await tidyNote(session.access_token, draft);
      setDraft(tidied);
      await saveDraft(tidied);
    } catch (error) {
      const message = error instanceof Error ? error.message : copy.errors.generic;
      setError(message);
    } finally {
      setTidying(false);
    }
  }

  async function startRecording() {
    if (!session) return;
    setError(null);
    try {
      const getUserMedia = navigator.mediaDevices?.getUserMedia?.bind(navigator.mediaDevices);
      if (!getUserMedia || typeof window.MediaRecorder === "undefined") {
        setError(copy.errors.recordingUnsupported);
        return;
      }

      await checkDailyQuota(session.access_token, "voice", "consume");
      const stream = await getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      chunksRef.current = [];
      stoppingRecordingRef.current = false;
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunksRef.current.push(event.data);
      };
      recorder.onstop = () => {
        stream.getTracks().forEach((track) => track.stop());
      };
      recorder.start();
      recorderRef.current = recorder;
      setRecording(true);

      if (recordingTimeoutRef.current !== null) {
        window.clearTimeout(recordingTimeoutRef.current);
      }
      recordingTimeoutRef.current = window.setTimeout(() => {
        if (recorderRef.current?.state === "recording") {
          void stopAndTranscribe();
        }
      }, recordingLimit * 1000);
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.microphone);
    }
  }

  async function stopAndTranscribe() {
    try {
      if (!session || !recorderRef.current || stoppingRecordingRef.current) return;
      const recorder = recorderRef.current;
      stoppingRecordingRef.current = true;
      if (recordingTimeoutRef.current !== null) {
        window.clearTimeout(recordingTimeoutRef.current);
        recordingTimeoutRef.current = null;
      }

      const stopped = new Promise<void>((resolve) => {
        recorder.addEventListener("stop", () => resolve(), { once: true });
      });

      const shouldWaitForStop = recorder.state === "recording" || recorder.state === "paused";
      if (shouldWaitForStop) {
        recorder.stop();
      }
      setRecording(false);
      if (shouldWaitForStop) {
        await stopped;
      }

      const blob = new Blob(chunksRef.current, { type: recorder.mimeType || "audio/webm" });
      recorderRef.current = null;
      stoppingRecordingRef.current = false;
      if (!blob.size) {
        setError(copy.errors.noRecording);
        return;
      }
      setTranscribing(true);
      setError(null);
      const base64 = await blobToBase64(blob);
      const rawText = await transcribeAudio(session.access_token, base64, blob.type || "audio/webm", false, {
        spokenLanguageMode: voiceLanguageMode,
        spokenLanguageHint: voiceLanguageMode === "prefer" ? voiceLanguageHint.trim() : null,
      });
      const text = await refineVoiceTranscript(session.access_token, rawText);
      if (activeNote) {
        setDraft(draft.trim() ? `${draft.trim()}\n\n${text}` : text);
      } else {
        createNote(text);
      }
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      recorderRef.current = null;
      stoppingRecordingRef.current = false;
      setRecording(false);
      setTranscribing(false);
    }
  }

  async function addTagToActiveNote() {
    if (!session?.user.id || !activeNote) return;
    const trimmed = newTagName.trim().replace(/^#/, "");
    if (!trimmed) return;

    const existing = visibleTags.find((tag) => tag.name.localeCompare(trimmed, undefined, { sensitivity: "accent" }) === 0);
    const tag = existing ?? makeTag(
      session.user.id,
      trimmed,
      autoColorHex(trimmed, tags),
      visibleTags.length
    );
    const nextTag = prepareTagForSave({ ...tag, colorHex: normalizeTagColorHex(tag.colorHex), lastUsedAt: new Date().toISOString() });
    const tagIds = Array.from(new Set([...(activeNote.tagIds ?? []), nextTag.id]));
    const nextNote = prepareNoteForSave({ ...activeNote, tagIds, content: draft });

    setTags((current) => existing ? current.map((item) => (item.id === nextTag.id ? nextTag : item)) : [...current, nextTag]);
    setNotes((current) => current.map((note) => (note.id === nextNote.id ? nextNote : note)));
    setNewTagName("");
    setSaving(true);
    setError(null);
    try {
      await pushChanges({ notes: [nextNote], tags: [nextTag] });
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      setSaving(false);
    }
  }

  async function removeTagFromActiveNote(tagId: string) {
    if (!activeNote) return;
    const nextTagIds = (activeNote.tagIds ?? []).filter((id) => id !== tagId);
    const nextNote = prepareNoteForSave({ ...activeNote, tagIds: nextTagIds, content: draft });
    setNotes((current) => current.map((note) => (note.id === nextNote.id ? nextNote : note)));
    setSaving(true);
    setError(null);
    try {
      await pushChanges({ notes: [nextNote] });
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      setSaving(false);
    }
  }

  async function applySourceURL() {
    if (!activeNote) return;
    const metadata = metadataFromURL(sourceURLDraft);
    if (!metadata) {
      setError(copy.errors.invalidSourceURL);
      return;
    }
    await saveDraft(draft, {
      sourceURL: metadata.url,
      sourceTitle: metadata.title,
      sourcePlatformID: metadata.platformID,
      sourcePlatformName: metadata.platformName,
      sourceHost: metadata.host,
      sourceCapturedAt: new Date().toISOString(),
    });
  }

  async function clearSourceURL() {
    if (!activeNote) return;
    setSourceURLDraft("");
    await saveDraft(draft, {
      sourceURL: null,
      sourceTitle: null,
      sourcePlatformID: null,
      sourcePlatformName: null,
      sourceHost: null,
      sourceCapturedAt: null,
    });
  }

  async function toggleChecklist(index: number) {
    const nextContent = toggleChecklistItem(draft, index);
    setDraft(nextContent);
    await saveDraft(nextContent);
  }

  function toggleSavedRecipe(recipeId: string) {
    setSavedRecipeIds((current) => {
      if (current.includes(recipeId)) return current.filter((id) => id !== recipeId);
      return [...current, recipeId];
    });
    setSelectedRecipeId(recipeId);
  }

  async function executeSelectedRecipe() {
    if (!session || !selectedRecipe) return;
    const sourceNotes = recipeScope === "visible" ? visibleNotes.filter((note) => !note.deletedAt) : activeNote ? [activeNote] : [];
    if (sourceNotes.length === 0) {
      setError(copy.errors.emptyNote);
      return;
    }

    setRunningRecipe(true);
    setError(null);
    try {
      const notesForRecipe = sourceNotes.map((note) => (
        note.id === activeNote?.id ? { ...note, content: draft } : note
      ));
      const request = buildAgentRecipeRequest(selectedRecipe, notesForRecipe, recipeInstruction);
      const result = await runAgentRecipe(session.access_token, request.prompt, request.systemPrompt);
      const note = prepareNoteForSave({ ...makeEmptyNote(session.user.id), content: result });
      setNotes((current) => [note, ...current]);
      setFeedMode("active");
      setMainPanel("notes");
      setActiveId(note.id);
      setDraft(result);
      await pushChanges({ notes: [note] });
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      setRunningRecipe(false);
    }
  }

  async function signOut() {
    await supabase.auth.signOut();
    setSession(null);
    setNotes([]);
    setTags([]);
    setActiveId(null);
    setCursor(null);
    setSubscription(null);
  }

  async function startCheckout() {
    if (!session) return;
    setCheckoutLoading(true);
    setError(null);
    try {
      const response = await createCreemCheckout(session.access_token, "yearly");
      window.location.assign(response.checkoutUrl);
    } catch (error) {
      setError(error instanceof Error ? error.message : copy.errors.generic);
    } finally {
      setCheckoutLoading(false);
    }
  }

  if (!authReady) {
    return (
      <main className="app-loading">
        <Loader2 className="spin" />
      </main>
    );
  }

  if (!session) {
    return <AuthPanel onAuthenticated={() => void supabase.auth.getSession().then(({ data }) => setSession(data.session))} />;
  }

  const panelTitle = copy.app.panels[mainPanel].title;

  return (
    <main className="web-app-shell">
      <aside className="sidebar">
        <div className="sidebar-top">
          <a className="brand-lockup" href="/">
            <img src="/assets/chillnote-logo.png" alt="" />
            <span>{copy.productName}</span>
          </a>
          <button className="icon-button" onClick={signOut} aria-label={copy.auth.signOut} title={copy.auth.signOut}>
            <LogOut size={18} />
          </button>
        </div>

        <div className="subscription-strip">
          <div>
            <span>{copy.app.subscription}</span>
            <strong>{isPro ? copy.app.pro : copy.app.free}</strong>
          </div>
          {isPro ? null : (
            <button className="mini-button" onClick={startCheckout} disabled={checkoutLoading}>
              {checkoutLoading ? <Loader2 className="spin" size={15} /> : <CreditCard size={15} />}
              {checkoutLoading ? copy.app.checkoutLoading : copy.app.upgrade}
            </button>
          )}
        </div>

        <nav className="app-nav" aria-label={copy.app.sections}>
          <button className={mainPanel === "notes" ? "active" : ""} onClick={() => setMainPanel("notes")}>
            <FileText size={16} />
            {copy.app.panels.notes.nav}
          </button>
          <button className={mainPanel === "stats" ? "active" : ""} onClick={() => setMainPanel("stats")}>
            <BarChart3 size={16} />
            {copy.app.panels.stats.nav}
          </button>
          <button className={mainPanel === "skills" ? "active" : ""} onClick={() => setMainPanel("skills")}>
            <Bot size={16} />
            {copy.app.panels.skills.nav}
          </button>
          <button className={mainPanel === "settings" ? "active" : ""} onClick={() => setMainPanel("settings")}>
            <SettingsIcon size={16} />
            {copy.app.panels.settings.nav}
          </button>
        </nav>

        <div className="feed-tabs" role="tablist" aria-label={copy.app.feedMode}>
          <button className={feedMode === "active" ? "active" : ""} onClick={() => setFeedMode("active")}>
            {copy.app.activeNotes}
          </button>
          <button className={feedMode === "trash" ? "active" : ""} onClick={() => setFeedMode("trash")}>
            {copy.app.trash}
          </button>
        </div>

        <div className="search-box">
          <Search size={17} />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={copy.app.searchPlaceholder} />
        </div>

        <button className="new-note-button" onClick={() => createNote()}>
          <Plus size={18} />
          {copy.app.newNote}
        </button>

        <div className="tag-filter-list" aria-label={copy.app.tags}>
          <button className={selectedTagId === null ? "active" : ""} onClick={() => setSelectedTagId(null)}>
            <Tag size={14} />
            {copy.app.allTags}
          </button>
          {visibleTags.map((tag) => (
            <button
              key={tag.id}
              className={selectedTagId === tag.id ? "active" : ""}
              onClick={() => setSelectedTagId(tag.id)}
            >
              <span className="tag-dot" style={{ background: normalizeTagColorHex(tag.colorHex) }} />
              {tag.name}
            </button>
          ))}
        </div>

        <div className="notes-list" aria-label={copy.app.noteCount}>
          {visibleNotes.map((note) => {
            const notePreview = previewPlainText(note.content).trim();
            return (
              <button
                key={note.id}
                className={`note-row ${note.id === activeId ? "active" : ""}`}
                onClick={() => setActiveId(note.id)}
              >
                <span>{notePreview.split("\n")[0] || copy.app.emptyTitle}</span>
                <small>{note.pinnedAt ? `${copy.app.pinned} · ` : ""}{formatDate(note.createdAt)}</small>
              </button>
            );
          })}
        </div>
      </aside>

      <section className="workspace">
        <header className="workspace-header">
          <div>
            <h1>{panelTitle}</h1>
          </div>
          {mainPanel === "notes" ? (
          <div className="toolbar">
            <button className="ghost-button" onClick={() => void refreshAll()} disabled={syncing}>
              {syncing ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
              {syncing ? copy.app.syncing : copy.app.sync}
            </button>
            <button className="ghost-button" onClick={togglePin} disabled={!activeNote || saving}>
              {activeNote?.pinnedAt ? <PinOff size={17} /> : <Pin size={17} />}
              {activeNote?.pinnedAt ? copy.app.unpin : copy.app.pin}
            </button>
            <button className="ghost-button" onClick={recording ? stopAndTranscribe : startRecording} disabled={transcribing}>
              {recording ? <Square size={17} /> : <Mic size={17} />}
              {recording ? copy.app.stopRecording : transcribing ? copy.app.transcribing : copy.app.startRecording}
            </button>
            <button className="ghost-button" onClick={tidyDraft} disabled={tidying || !draft.trim()}>
              {tidying ? <Loader2 className="spin" size={17} /> : <Sparkles size={17} />}
              {tidying ? copy.app.tidying : copy.app.tidy}
            </button>
            <button className="primary-button compact" onClick={() => void saveDraft()} disabled={saving || !activeNote || Boolean(activeNote.deletedAt)}>
              {saving ? <Loader2 className="spin" size={17} /> : <Check size={17} />}
              {saving ? copy.app.saving : copy.app.save}
            </button>
          </div>
          ) : null}
        </header>

        {error ? <div className="error-banner">{error}</div> : null}

        <div className="editor-shell">
          {mainPanel === "notes" ? (
          activeNote ? (
            <>
              <div className="metadata-bar">
                <div className="tag-editor">
                  {activeTags.map((tag) => (
                    <button key={tag.id} className="tag-chip" onClick={() => void removeTagFromActiveNote(tag.id)}>
                      <span className="tag-dot" style={{ background: normalizeTagColorHex(tag.colorHex) }} />
                      {tag.name}
                      <X size={13} />
                    </button>
                  ))}
                  <input
                    value={newTagName}
                    onChange={(event) => setNewTagName(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") {
                        event.preventDefault();
                        void addTagToActiveNote();
                      }
                    }}
                    placeholder={copy.app.addTagPlaceholder}
                  />
                </div>
                <div className="source-editor">
                  <Link2 size={16} />
                  <input
                    value={sourceURLDraft}
                    onChange={(event) => setSourceURLDraft(event.target.value)}
                    onBlur={() => {
                      if (sourceURLDraft && sourceURLDraft !== activeNote.sourceURL) void applySourceURL();
                    }}
                    placeholder={copy.app.sourcePlaceholder}
                  />
                  {sourceMetadata ? (
                    <a href={sourceMetadata.url} target="_blank" rel="noreferrer" title={sourceMetadata.title}>
                      <ExternalLink size={16} />
                    </a>
                  ) : null}
                  {activeNote.sourceURL ? (
                    <button className="icon-button small" onClick={clearSourceURL} aria-label={copy.app.clearSource}>
                      <X size={14} />
                    </button>
                  ) : null}
                </div>
              </div>

              {sourceMetadata ? (
                <div className="source-card">
                  <strong>{sourceMetadata.platformName}</strong>
                  <span>{sourceMetadata.title}</span>
                  <small>{sourceMetadata.host}</small>
                </div>
              ) : null}

              {checklist ? (
                <div className="checklist-panel">
                  {checklist.items.map((item, index) => (
                    <button key={`${item.text}-${index}`} onClick={() => void toggleChecklist(index)}>
                      <CheckSquare size={16} />
                      <span className={item.isDone ? "done" : ""}>{item.text || copy.app.emptyChecklistItem}</span>
                    </button>
                  ))}
                </div>
              ) : null}

              <MarkdownRichEditor
                value={draft}
                onChange={setDraft}
                placeholder={copy.app.editorPlaceholder}
                disabled={Boolean(activeNote.deletedAt)}
              />
              <footer className="editor-footer">
                <span>
                  {copy.app.lastSynced}: {formatDate(status)}
                  {activeNote.deletedAt ? ` · ${daysRemainingInTrash(activeNote.deletedAt)} ${copy.app.daysRemaining}` : ""}
                </span>
                {activeNote.deletedAt ? (
                  <div className="footer-actions">
                    <button className="ghost-button" onClick={restoreActiveNote} disabled={saving}>
                      <RotateCcw size={16} />
                      {copy.app.restore}
                    </button>
                    <button className="danger-button" onClick={hardDeleteActiveNote} disabled={saving}>
                      <Trash2 size={16} />
                      {copy.app.deleteForever}
                    </button>
                  </div>
                ) : (
                  <button className="danger-button" onClick={softDeleteActiveNote} disabled={saving}>
                    <Trash2 size={16} />
                    {copy.app.delete}
                  </button>
                )}
              </footer>
            </>
          ) : (
            <div className="empty-state">
              <h2>{copy.app.emptyTitle}</h2>
              <p>{copy.app.emptyBody}</p>
              <button className="primary-button compact" onClick={() => createNote()}>
                <Plus size={17} />
                {copy.app.newNote}
              </button>
            </div>
          )
          ) : mainPanel === "stats" ? (
            <div className="panel-content">
              <div className="stats-grid">
                <article className="stat-tile">
                  <FileText size={20} />
                  <span>{copy.stats.totalNotes}</span>
                  <strong>{notesStats.totalNotes}</strong>
                </article>
                <article className="stat-tile">
                  <Tag size={20} />
                  <span>{copy.stats.totalTags}</span>
                  <strong>{notesStats.totalTags}</strong>
                </article>
                <article className="stat-tile">
                  <Plus size={20} />
                  <span>{copy.stats.todayNew}</span>
                  <strong>{notesStats.todayNew}</strong>
                </article>
                <article className="stat-tile">
                  <BarChart3 size={20} />
                  <span>{copy.stats.weekNew}</span>
                  <strong>{notesStats.weekNew}</strong>
                </article>
              </div>
              <section className="settings-section">
                <h2>{copy.stats.dataSourceTitle}</h2>
                <p>{copy.stats.dataSourceBody}</p>
              </section>
            </div>
          ) : mainPanel === "skills" ? (
            <div className="panel-content skills-layout">
              <section className="recipe-browser">
                <div className="recipe-tabs">
                  {(Object.keys(recipeCategoryLabels) as AgentRecipeCategory[]).map((category) => (
                    <button
                      key={category}
                      className={selectedRecipeCategory === category ? "active" : ""}
                      onClick={() => setSelectedRecipeCategory(category)}
                    >
                      {recipeCategoryLabels[category]}
                    </button>
                  ))}
                </div>
                <div className="recipe-grid">
                  {libraryRecipes.map((recipe) => {
                    const isSaved = savedRecipeIds.includes(recipe.id);
                    const isSelected = selectedRecipe.id === recipe.id;
                    return (
                      <article className={`recipe-card ${isSelected ? "selected" : ""}`} key={recipe.id}>
                        <button className="recipe-main" onClick={() => setSelectedRecipeId(recipe.id)}>
                          <span className="recipe-icon">{recipe.icon}</span>
                          <strong>{recipe.name}</strong>
                          <small>{recipe.description}</small>
                        </button>
                        <button className="mini-button" onClick={() => toggleSavedRecipe(recipe.id)}>
                          {isSaved ? copy.skills.added : copy.skills.add}
                        </button>
                      </article>
                    );
                  })}
                </div>
              </section>

              <aside className="run-panel">
                <h2>{copy.skills.runTitle}</h2>
                <div className="selected-recipe">
                  <span className="recipe-icon">{selectedRecipe.icon}</span>
                  <div>
                    <strong>{selectedRecipe.name}</strong>
                    <p>{selectedRecipe.description}</p>
                  </div>
                </div>

                <label className="field-label">
                  {copy.skills.savedSkills}
                  <select value={selectedRecipeId} onChange={(event) => setSelectedRecipeId(event.target.value)}>
                    {savedRecipes.map((recipe) => (
                      <option key={recipe.id} value={recipe.id}>{recipe.name}</option>
                    ))}
                    {!savedRecipes.some((recipe) => recipe.id === selectedRecipe.id) ? (
                      <option value={selectedRecipe.id}>{selectedRecipe.name}</option>
                    ) : null}
                  </select>
                </label>

                <div className="segmented-control">
                  <button className={recipeScope === "active" ? "active" : ""} onClick={() => setRecipeScope("active")}>
                    {copy.skills.activeNote}
                  </button>
                  <button className={recipeScope === "visible" ? "active" : ""} onClick={() => setRecipeScope("visible")}>
                    {copy.skills.visibleNotes}
                  </button>
                </div>

                {selectedRecipe.requiresInstruction ? (
                  <label className="field-label">
                    {copy.skills.targetLanguage}
                    <input value={recipeInstruction} onChange={(event) => setRecipeInstruction(event.target.value)} />
                  </label>
                ) : null}

                <p className="muted-copy">{copy.skills.outputNoteHint}</p>
                <button className="primary-button compact" onClick={executeSelectedRecipe} disabled={runningRecipe || !selectedRecipe}>
                  {runningRecipe ? <Loader2 className="spin" size={17} /> : <Sparkles size={17} />}
                  {runningRecipe ? copy.skills.running : copy.skills.run}
                </button>
              </aside>
            </div>
          ) : (
            <div className="panel-content settings-grid">
              <section className="settings-section">
                <h2>{copy.settings.account}</h2>
                <div className="settings-row">
                  <span>{copy.settings.email}</span>
                  <strong>{session.user.email ?? copy.settings.unknownEmail}</strong>
                </div>
                <div className="settings-row">
                  <span>{copy.app.subscription}</span>
                  <strong>{isPro ? copy.app.pro : copy.app.free}</strong>
                </div>
                {isPro ? null : (
                  <button className="primary-button compact" onClick={startCheckout} disabled={checkoutLoading}>
                    {checkoutLoading ? <Loader2 className="spin" size={17} /> : <CreditCard size={17} />}
                    {copy.app.upgrade}
                  </button>
                )}
              </section>

              <section className="settings-section">
                <h2>{copy.settings.data}</h2>
                <div className="settings-row">
                  <span>{copy.settings.syncStatus}</span>
                  <strong>{formatDate(status)}</strong>
                </div>
                <button className="ghost-button" onClick={() => void refreshAll()} disabled={syncing}>
                  {syncing ? <Loader2 className="spin" size={17} /> : <RefreshCw size={17} />}
                  {copy.app.sync}
                </button>
              </section>

              <section className="settings-section">
                <h2>{copy.settings.voiceLanguage}</h2>
                <div className="segmented-control">
                  <button className={voiceLanguageMode === "auto" ? "active" : ""} onClick={() => setVoiceLanguageMode("auto")}>
                    {copy.settings.autoDetect}
                  </button>
                  <button className={voiceLanguageMode === "prefer" ? "active" : ""} onClick={() => setVoiceLanguageMode("prefer")}>
                    {copy.settings.preferredLanguage}
                  </button>
                </div>
                {voiceLanguageMode === "prefer" ? (
                  <label className="field-label">
                    {copy.settings.languageHint}
                    <input value={voiceLanguageHint} onChange={(event) => setVoiceLanguageHint(event.target.value)} placeholder="zh-Hans, en, ja..." />
                  </label>
                ) : (
                  <p className="muted-copy">{copy.settings.autoDetectHelp}</p>
                )}
              </section>

              <section className="settings-section">
                <h2>{copy.settings.support}</h2>
                <a className="settings-link" href="/privacy">{copy.settings.privacy}</a>
                <a className="settings-link" href="/terms">{copy.settings.terms}</a>
                <button className="danger-button" onClick={signOut}>
                  <LogOut size={16} />
                  {copy.auth.signOut}
                </button>
              </section>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}
