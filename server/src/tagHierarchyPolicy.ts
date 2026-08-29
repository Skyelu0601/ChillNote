import { syncIdentityKey } from "./syncIdentity.js";

export type TagParentEdge = {
  id: string;
  parentId: string | null;
};

export type SanitizedTagParents = {
  parentByTagId: Map<string, string | null>;
  adjustedTagIds: Set<string>;
};

/**
 * Applies the requested parent edges in a deterministic order while keeping
 * the resulting active-tag graph acyclic. Every touched edge is removed from
 * the starting graph first, so a valid reversal/move is not rejected merely
 * because the old edge still exists. An edge that would close a cycle is
 * safely converted to a root edge (`parentId = null`).
 */
export function sanitizeTagParentChanges(
  current: TagParentEdge[],
  proposed: TagParentEdge[]
): SanitizedTagParents {
  const proposedByKey = new Map(proposed.map((edge) => [syncIdentityKey(edge.id), edge]));
  const graph = new Map<string, string | null>();
  for (const edge of current) {
    const key = syncIdentityKey(edge.id);
    graph.set(
      key,
      proposedByKey.has(key) || !edge.parentId ? null : syncIdentityKey(edge.parentId)
    );
  }
  for (const edge of proposed) {
    const key = syncIdentityKey(edge.id);
    if (!graph.has(key)) graph.set(key, null);
  }

  const parentByTagId = new Map<string, string | null>();
  const adjustedTagIds = new Set<string>();
  const ordered = [...proposed].sort((left, right) =>
    syncIdentityKey(left.id).localeCompare(syncIdentityKey(right.id))
  );
  for (const edge of ordered) {
    const key = syncIdentityKey(edge.id);
    const parentKey = edge.parentId ? syncIdentityKey(edge.parentId) : null;
    if (parentKey && wouldCreateCycle(graph, key, parentKey)) {
      graph.set(key, null);
      parentByTagId.set(key, null);
      adjustedTagIds.add(key);
    } else {
      graph.set(key, parentKey);
      parentByTagId.set(key, edge.parentId);
    }
  }

  return { parentByTagId, adjustedTagIds };
}

function wouldCreateCycle(
  graph: Map<string, string | null>,
  tagId: string,
  candidateParentId: string
): boolean {
  const visited = new Set<string>();
  let current: string | null | undefined = candidateParentId;
  while (current) {
    if (current === tagId) return true;
    if (visited.has(current)) return true;
    visited.add(current);
    current = graph.get(current);
  }
  return false;
}
