---
name: hwp-edit
description: Read and edit existing HWP documents through Hancom COM on Windows, including body text, formatting, and complex table forms, then verify saved content and rendered page images.
---

# Edit existing HWP documents

No Markdown manuscript, Pandoc, IR, or report template is required. Work from the user's supplied HWP and facts. Do not invent missing answers.

## Workflow

1. Inspect the supplied HWP using `scripts/hwp-edit.ps1 -Mode Inspect` to export HWPML, text, indexed fields, and nested table/cell inventory. Read the relevant paragraphs, styles, controls, and surrounding context; use rendered pages where layout matters. Inventory XML paths are not COM cursor coordinates.
2. Identify the exact requested changes and protected content. For text edits, confirm the original passage and occurrence count. For table forms, map labels to their actual cells; account for merged and nested cells. Do not invent missing facts.
3. Use `-Mode Edit -TaskScript ...` for general text, paragraph, character-formatting, or native table operations. Read [native-edit.md](references/native-edit.md) and create task-specific COM callbacks `Invoke-HwpEdit` and `Test-HwpEdit`. Use `-Mode Fill` with a JSON plan when indexed named fields suffice. Duplicate field names require the explicit `{{n}}` suffix from inspection.
4. The runner edits a temporary copy, saves, closes, reopens, verifies intended edits, checks the source hash, and publishes a separate HWP only on success. It preserves table geometry by default. When the user requests table structure/width changes, use `-AllowTableGeometryChange` in Edit mode and make the task verifier assert the requested geometry and protected surrounding structure. Do not disable preservation checks just to make an unexpected change pass.
5. Render the saved output with `-Mode Render`, inspect the affected PNG pages and spillover pages, and enlarge relevant regions when necessary. Check text clipping, wrapping, spacing, fonts, alignment, cell overflow, object overlap, and pagination. Correct through COM and repeat if needed. PDF is unnecessary.
6. Deliver the edited HWP and a concise account of changes or unresolved entries. State which pages were visually checked. Syntax checks, XML comparisons, and successful saving alone are not visual verification.

## Execution

Use Windows PowerShell 7 x64 in STA and an interactive desktop session. Windows PowerShell 5.1 can be used where local execution policy permits, but was not execution-tested here. Do not change machine/user execution policies to run the skill.

```powershell
pwsh.exe -NoProfile -STA -File "<skill>/scripts/hwp-edit.ps1" -Mode Inspect -InputPath "C:\work\form.hwp" -OutputPath "C:\work\inspection"
pwsh.exe -NoProfile -STA -File "<skill>/scripts/hwp-edit.ps1" -Mode Edit -InputPath "C:\work\document.hwp" -OutputPath "C:\work\edited.hwp" -TaskScript "C:\work\edit-task.ps1"
pwsh.exe -NoProfile -STA -File "<skill>/scripts/hwp-edit.ps1" -Mode Fill -InputPath "C:\work\form.hwp" -OutputPath "C:\work\filled.hwp" -PlanPath "C:\work\plan.json"
pwsh.exe -NoProfile -STA -File "<skill>/scripts/hwp-edit.ps1" -Mode Render -InputPath "C:\work\filled.hwp" -OutputPath "C:\work\pages" -Dpi 150
```

`-Mode ValidatePlan -PlanPath ...` validates plan syntax without launching Hancom. Render defaults to all pages; `-Pages 1,3` uses human page numbers. Internally `CreatePageImage` uses zero-based pages, 24-bit BMP, then converts to PNG without a PDF step.

Plan shape (replace these names and values using the inspected document):

```json
{
  "sourceSha256": "64 hexadecimal characters from inspection.json",
  "fields": [
    {"name": "applicant{{0}}", "expected": "", "text": "Provided applicant name"}
  ]
}
```

`expected` must match existing field text, including whitespace (line endings are normalized). Multi-line answers are allowed. Values containing the COM field separator U+0002 are rejected. Prior content is checked for **every** target before any field write.

## Preservation and prerequisites

- Keep the source unchanged. Preserve content, controls, and formatting outside the requested change. Apply requested body-text and formatting edits directly through COM. Avoid rebuilding tables, flattening merged cells, or full-document XML reimport as a shortcut. In form-filling tasks, retain the supplied layout and shorten wording within the user's meaning before changing fonts or dimensions; resolve material content/layout choices from the user's request.
- Use documented Hancom COM actions. Do not use keyboard/mouse automation or terminate user-owned Hancom processes. The runner stops when Hwp/Hwp64 is already running.
- Require installed Hancom, the user's registered `FilePathCheckerModuleExample` DLL, and successful `RegisterModule` before opening a document. For a missing module or an installation/migration request, read [security-module.md](references/security-module.md). The skill distributes no Hancom DLL. Document-edit commands never install modules or alter registry settings; use the separate setup helper only within an explicit setup request. An environment/permission failure is not evidence the document is invalid.
- HWP only in this first version. HWPX is not tested. Password, repair, and data-loss prompts require stopping rather than accepting dialogs.
- Scripts are an initial implementation; verify with a disposable representative document before relying on live COM behavior. Read [validation.md](references/validation.md) for the actual validation status.
