import type { Note } from "@prisma/client";
import type { NoteDTO } from "./types.js";
import { syncIdentityKey } from "./syncIdentity.js";

type ImportNote = Pick<Note,
  "content" | "sourceURL" | "section" | "deletedAt" | "serverDeletedAt" | "pinnedAt"
  | "importStatus" | "importJobId" | "importErrorCode" | "importStartedAt" | "importCompletedAt"
> & { tags: Array<{ id: string }> };

function isPending(status: string | null | undefined): boolean {
  return status === "queued" || status === "processing";
}

// Ignore enqueue timestamps and source enrichment, but never discard changes to
// the text, location, tags, deletion or pinning when accepting server authority.
function sameActiveNoteValues(existing: ImportNote, incoming: NoteDTO): boolean {
  if (existing.content !== incoming.content
    || existing.sourceURL !== incoming.sourceURL
    || existing.section !== (incoming.section ?? "inbox")
    || existing.deletedAt || existing.serverDeletedAt || incoming.deletedAt
    || existing.pinnedAt || incoming.pinnedAt) return false;

  // Omitted tags mean "leave the relationship unchanged" in upsertNote.
  if (incoming.tagIds == null) return true;
  const current = new Set(existing.tags.map((tag) => syncIdentityKey(tag.id)));
  const uploaded = new Set(incoming.tagIds.map(syncIdentityKey));
  return current.size === uploaded.size && [...uploaded].every((id) => current.has(id));
}

export function shouldPreservePendingImport(existing: ImportNote | null, incoming: NoteDTO): boolean {
  return !!existing
    && isPending(existing.importStatus) && isPending(incoming.importStatus)
    && !!existing.importJobId && !!existing.sourceURL
    // The sync response can arrive before the enqueue response supplies jobId.
    && (!incoming.importJobId || syncIdentityKey(incoming.importJobId) === syncIdentityKey(existing.importJobId))
    && sameActiveNoteValues(existing, incoming);
}

export function clearImportMetadata(incoming: NoteDTO): NoteDTO {
  return {
    ...incoming,
    importStatus: null,
    importJobId: null,
    importErrorCode: null,
    importStartedAt: null,
    importCompletedAt: null
  };
}

// v3 has no durable mutation IDs. A retry after losing the normalization ACK
// must not create another conflict copy of an already detached draft.
export function isDetachedImportReplay(existing: ImportNote | null, incoming: NoteDTO): boolean {
  return !!existing
    && existing.importStatus == null && existing.importJobId == null
    && existing.importErrorCode == null && existing.importStartedAt == null && existing.importCompletedAt == null
    && sameActiveNoteValues(existing, incoming);
}
