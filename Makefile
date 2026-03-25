.PHONY: lint-i18n i18n-normalize i18n-reports i18n-stale i18n-stale-apply i18n-empty i18n-empty-apply

lint-i18n:
	./scripts/i18n/lint_i18n.py

i18n-normalize:
	./scripts/i18n/normalize_xcstrings.py

i18n-reports:
	./scripts/i18n/generate_reports.py

i18n-stale:
	./scripts/i18n/cleanup_stale_xcstrings.py

i18n-stale-apply:
	./scripts/i18n/cleanup_stale_xcstrings.py --apply

i18n-empty:
	./scripts/i18n/cleanup_empty_xcstrings.py

i18n-empty-apply:
	./scripts/i18n/cleanup_empty_xcstrings.py --apply
