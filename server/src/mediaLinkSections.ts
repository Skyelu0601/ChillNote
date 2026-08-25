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
    showDescription: input?.showDescription ?? false,
    showAuthor: input?.showAuthor ?? false,
    showHook: input?.showHook ?? false,
    showTranscript: input?.showTranscript ?? true
  };

  if (Object.values(normalized).some(Boolean)) {
    return normalized;
  }

  return {
    showDescription: false,
    showAuthor: false,
    showHook: false,
    showTranscript: true
  };
}
