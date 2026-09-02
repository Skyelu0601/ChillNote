export const supportedLinkImportContentLocales = [
  "de",
  "en",
  "es",
  "fr",
  "ja",
  "ko",
  "zh-Hans",
  "zh-Hant"
] as const;

export type LinkImportContentLocale = typeof supportedLinkImportContentLocales[number];

export type LinkImportContentStrings = {
  descriptionHeading: string;
  authorHeading: string;
  hookHeading: string;
  transcriptHeading: string;
  unavailable: string;
  unknownAuthor: string;
};

const stringsByLocale: Record<LinkImportContentLocale, LinkImportContentStrings> = {
  de: {
    descriptionHeading: "Beschreibung",
    authorHeading: "Autor",
    hookHeading: "Aufhänger",
    transcriptHeading: "Transkript",
    unavailable: "Nicht verfügbar",
    unknownAuthor: "Unbekannter Autor"
  },
  en: {
    descriptionHeading: "Description",
    authorHeading: "Author",
    hookHeading: "Hook",
    transcriptHeading: "Transcript",
    unavailable: "Unavailable",
    unknownAuthor: "Unknown author"
  },
  es: {
    descriptionHeading: "Descripción",
    authorHeading: "Autor",
    hookHeading: "Gancho",
    transcriptHeading: "Transcripción",
    unavailable: "No disponible",
    unknownAuthor: "Autor desconocido"
  },
  fr: {
    descriptionHeading: "Description",
    authorHeading: "Auteur",
    hookHeading: "Accroche",
    transcriptHeading: "Transcription",
    unavailable: "Indisponible",
    unknownAuthor: "Auteur inconnu"
  },
  ja: {
    descriptionHeading: "説明",
    authorHeading: "作者",
    hookHeading: "フック",
    transcriptHeading: "文字起こし",
    unavailable: "取得できません",
    unknownAuthor: "不明な作者"
  },
  ko: {
    descriptionHeading: "설명",
    authorHeading: "작성자",
    hookHeading: "훅",
    transcriptHeading: "녹취록",
    unavailable: "가져올 수 없음",
    unknownAuthor: "알 수 없는 작성자"
  },
  "zh-Hans": {
    descriptionHeading: "描述",
    authorHeading: "作者",
    hookHeading: "开场钩子",
    transcriptHeading: "转写文字",
    unavailable: "无法获取",
    unknownAuthor: "未知作者"
  },
  "zh-Hant": {
    descriptionHeading: "描述",
    authorHeading: "作者",
    hookHeading: "開場鉤子",
    transcriptHeading: "轉寫文字",
    unavailable: "無法取得",
    unknownAuthor: "未知作者"
  }
};

export function normalizeLinkImportContentLocale(locale?: string | null): LinkImportContentLocale {
  const normalized = locale?.trim().replace(/_/g, "-");
  if (!normalized) return "en";

  const lowercased = normalized.toLowerCase();
  if (lowercased.startsWith("zh-")) {
    const subtags = lowercased.split("-");
    if (subtags.includes("hant") || subtags.some((item) => ["tw", "hk", "mo"].includes(item))) {
      return "zh-Hant";
    }
    return "zh-Hans";
  }

  const baseLanguage = lowercased.split("-")[0];
  return supportedLinkImportContentLocales.find((item) => item === baseLanguage) ?? "en";
}

export function linkImportContentStrings(locale?: string | null): LinkImportContentStrings {
  return stringsByLocale[normalizeLinkImportContentLocale(locale)];
}

export function preferredLanguageFromHeader(
  header: string | string[] | undefined
): string | undefined {
  const rawValue = Array.isArray(header) ? header[0] : header;
  return rawValue
    ?.split(",")[0]
    ?.split(";")[0]
    ?.trim() || undefined;
}
