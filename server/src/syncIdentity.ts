const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUUIDSyncIdentity(id: string): boolean {
  return UUID_PATTERN.test(id);
}

/**
 * UUIDs are case-insensitive identifiers even though PostgreSQL text keys are not.
 * Non-UUID IDs are kept byte-for-byte for backward compatibility.
 */
export function syncIdentityKey(id: string): string {
  return isUUIDSyncIdentity(id) ? id.toLowerCase() : id;
}

export function normalizeNewSyncEntityId(id: string): string {
  return syncIdentityKey(id);
}

export function pickLatestBySyncIdentity<T extends { id: string }>(
  items: T[],
  timestamp: (item: T) => number
): Map<string, T> {
  const deduped = new Map<string, T>();
  for (const item of items) {
    const key = syncIdentityKey(item.id);
    const current = deduped.get(key);
    if (!current || timestamp(item) > timestamp(current)) {
      deduped.set(key, item);
    }
  }
  return deduped;
}
