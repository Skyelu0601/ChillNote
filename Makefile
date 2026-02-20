.PHONY: lint-i18n i18n-normalize i18n-reports

lint-i18n:
	./scripts/i18n/lint_i18n.py

i18n-normalize:
	./scripts/i18n/normalize_xcstrings.py

i18n-reports:
	./scripts/i18n/generate_reports.py
