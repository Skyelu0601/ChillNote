import assert from "node:assert/strict";
import test from "node:test";
import {
  linkImportContentStrings,
  normalizeLinkImportContentLocale,
  preferredLanguageFromHeader,
  supportedLinkImportContentLocales
} from "./linkImportLocalization.js";

test("provides a localized transcript heading for every supported app language", () => {
  const expected = new Map([
    ["de", "Transkript"],
    ["en", "Transcript"],
    ["es", "Transcripción"],
    ["fr", "Transcription"],
    ["ja", "文字起こし"],
    ["ko", "녹취록"],
    ["pt-BR", "Transcrição"],
    ["pt-PT", "Transcrição"],
    ["zh-Hans", "转写文字"],
    ["zh-Hant", "轉寫文字"]
  ]);

  assert.deepEqual([...supportedLinkImportContentLocales], [...expected.keys()]);
  for (const [locale, heading] of expected) {
    assert.equal(linkImportContentStrings(locale).transcriptHeading, heading);
  }
});

test("normalizes system locale variants and safely falls back to English", () => {
  assert.equal(normalizeLinkImportContentLocale("zh-TW"), "zh-Hant");
  assert.equal(normalizeLinkImportContentLocale("zh-HK"), "zh-Hant");
  assert.equal(normalizeLinkImportContentLocale("zh-CN"), "zh-Hans");
  assert.equal(normalizeLinkImportContentLocale("fr-CA"), "fr");
  assert.equal(normalizeLinkImportContentLocale("unknown"), "en");
  assert.equal(normalizeLinkImportContentLocale(undefined), "en");
});

test("extracts the preferred locale from an Accept-Language header", () => {
  assert.equal(preferredLanguageFromHeader("zh-Hant-TW,zh-Hant;q=0.9,en;q=0.8"), "zh-Hant-TW");
  assert.equal(preferredLanguageFromHeader(["fr-CA,fr;q=0.9"]), "fr-CA");
  assert.equal(preferredLanguageFromHeader(undefined), undefined);
});

test("Portuguese system tags preserve the regional variant and never fall back to English", () => {
  for (const locale of ["pt", "pt-BR", " PT_br ", "pt-Latn-BR"]) {
    assert.equal(normalizeLinkImportContentLocale(locale), "pt-BR");
  }
  for (const locale of ["pt-PT", "pt_PT", "pt-AO", "pt-MZ", "pt-Latn-PT"]) {
    assert.equal(normalizeLinkImportContentLocale(locale), "pt-PT");
  }
  assert.equal(linkImportContentStrings("pt-BR").unknownAuthor, "Autor desconhecido");
  assert.equal(linkImportContentStrings("pt-PT").descriptionHeading, "Descrição");
});
