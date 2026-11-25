# Native HWP editing

## Body text and formatting

The Edit runner accepts document-specific COM callbacks; it is not a fixed report generator. Locate paragraphs by verified text and context, inspect their current styles, and apply only the requested change. Confirm occurrence counts before global replacement. Use native search/selection and InsertText for text changes; use documented CharShape/ParagraphShape actions for formatting. Before constructing an action, check [verified-api.md](verified-api.md) for the current build; anything missing there gets looked up, probed, and recorded as that file describes. Do not assume document positions survive an earlier insertion or deletion.

The verification callback must independently re-locate the targets and check the intended text, formatting, or structure before saving and again after reopen; `Read-HwpMarkup $Hwp` returns the open document as HWPML for checking shapes and structure. Preserve unrelated sections, headers, footers, images, fields, and native controls. For requested table geometry edits, `-AllowTableGeometryChange` suppresses only the default geometry equality check; the callback must assert the expected replacement geometry and unaffected tables.

## Unnamed, merged, and nested cells

The inventory records each table's XML path and each directly owned cell's attributes, paragraph text, and nested-table count. The row/column attributes describe native geometry. XML order and COM list IDs are different namespaces; never pass an inventory index to `SetPos`.

For task-specific editing, create a UTF-8-with-BOM PowerShell script defining:

```powershell
function Invoke-HwpEdit {
    param($Hwp)
    # Locate the exact cell using native controls, nearby labels, and/or
    # positions discovered in THIS document session; assert its old content.
    # Then insert only the requested text through COM.
}
function Test-HwpEdit {
    param($Hwp)
    # Re-locate targets after reopen, verify their values and context.
    # Return exactly one Boolean; suppress incidental COM output.
    return $true # Replace with actual assertions before use.
}
```

Run it with `-Mode Edit -TaskScript <path>`. The runner supplies the open working document. The task adapter must not save, open, close, quit, or publish documents itself. It must define BOTH callbacks. `Test-HwpEdit` runs before saving and after reopening; a dummy true callback does not constitute verification.

Useful native APIs, subject to checking against the sources in [api-sources.md](api-sources.md):

- `GetFieldList(1,0)`, `GetFieldList(1,1)`: all indexed fields / named cell fields.
- `MoveToField(name, $true, $true, $false)`: enter the particular indexed field.
- `GetFieldText`, `PutFieldText`: inspect and fill a field; unindexed PutFieldText can update ALL same-name fields, so always index.
- `GetPos` / `SetPos`: native list, paragraph, character positions discovered from the current document. Re-discover after operations that change structure.
- `InitScan` / `GetText` / `MovePos(201,0,0)` / `ReleaseScan`: discover scanned-text positions; confirm exact signatures in the local API docs before implementing by-ref calls.
- `MovePos(100..107,0,0)`: documented cell-direction movements; merged cells are not a rectangular spreadsheet, and transitions need postcondition checks.
- `AllReplace`: whole-document replacement after confirming the occurrence count; its return value does not report success (see [verified-api.md](verified-api.md)).
- `SelectText`: select a verified range within its current list; do not select across a cell boundary or a table control. Insert through the `InsertText` action, inheriting the target formatting.

Before editing an unnamed blank cell, prove its owning table and adjacent label from native control/cell context and the rendered page. Blank text alone is never a unique selector. If multiple paragraphs or controls are present, preserve them; do not select the whole cell casually. For checkbox glyphs, inspect the document's actual glyph/font rather than replacing controls with an assumed Unicode mark.

The bundled geometry check compares table nesting and row/column/span/width attributes; it does NOT prove that all unrelated text, images, borders, numbering, or native controls survived. The task-specific verifier must check protected content relevant to its edits. Visually inspect every affected page plus spillover pages. `CreatePageImage(path,pageIndex,dpi,24,'bmp')` renders directly in Hancom, including with its window hidden.

Keep the skill self-contained: bundle the editing instructions and helpers, while keeping Hancom DLLs, fonts, and proprietary API manuals outside the distributed skill.
