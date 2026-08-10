export type MediaLinkSections = {
  showDescription: boolean;
  showAuthor: boolean;
  showHook: boolean;
  showTranscript: boolean;
};

export function normalizeMediaLinkSections(
  input?: Partial<MediaLinkSections> | null
): MediaLinkSections {
  const normalized = {
    showDescription: input?.showDescription ?? true,
    showAuthor: input?.showAuthor ?? true,
    showHook: input?.showHook ?? true,
    showTranscript: input?.showTranscript ?? true
  };

  if (Object.values(normalized).some(Boolean)) {
    return normalized;
  }

  return {
    showDescription: true,
    showAuthor: true,
    showHook: true,
    showTranscript: true
  };
}
