# Validation status

PowerShell 7 checks passed: script parsing; skill frontmatter and linked resources; one valid plan; rejection of invalid hash, unindexed/duplicate field names, U+0002, missing expected text, and an empty plan; table geometry checks for text-only, merged-cell, and nested-table changes; protected-field verification and line-ending normalization. Windows PowerShell 5.1 execution has not been validated.

Live validation passed on a one-page form: HWPML/text/table inspection, two unnamed-cell insertions, twelve body-paragraph replacements, save/reopen checks, preservation of table geometry and source hash, and direct CreatePageImage export. The complete output page was visually checked. This establishes that sample, not arbitrary complex forms.

The security-module setup helper passed syntax checking, read-only registration/hash checking, and an Install -WhatIf preview. Actual installation, rollback, and migration have not been executed. No Hancom DLL or ZIP is bundled.

Before real use, verify a disposable form with named fields, duplicate field names, merged cells, nested tables, multiline answers, and at least two pages. Confirm source SHA-256 is unchanged, filled values persist after reopen, unrelated content/controls remain, and every affected page looks correct. Exercise wrong expected text and an existing output path: neither should publish an HWP. The runner requires an idle Hancom session and an already registered security module.
