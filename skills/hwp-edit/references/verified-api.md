# Verified API ledger

One entry per Hancom action, parameter set, or COM member that a probe has confirmed on a named build. An entry counts as verified only for the builds it lists; on any other build, re-run its probe first.

## Recording a feature

When an edit relies on an action, parameter set, or COM member with no entry here for the current build:

1. Look it up in the installed manuals (machine setup, [api-sources.md](api-sources.md)): action in `ActionTable_2504`, items in `ParameterSetTable_2504`, member in `HwpAutomation_2504` or the installed type library.
2. Write `scripts/probes/<feature>.ps1` defining `Invoke-HwpProbe -Hwp`, which builds what it needs (text, a table) with generic sample content on the blank document the probe runner provides, exercises the feature, and returns one ordered dictionary of observations. Keep it small and ASCII where possible, so it reruns on any machine.
3. Run it:

   ```powershell
   pwsh.exe -NoProfile -STA -File "<skill>/scripts/hwp-probe.ps1" -ProbeScript "<skill>/scripts/probes/<feature>.ps1" -OutputPath "<scratch>/<feature>.json"
   ```

   The runner uses its own Hancom process and saves nothing; the JSON records the build, observations, and any error. (`-InputPath` runs a probe on a copy of a document for one-off investigation; the JSON then names that document, so it stays in scratch.)
4. Add or update the entry below: how to call it, what was observed (including surprises), `verified: <build>, <date>`, the probe file, and the manual sections consulted. Entries and probe files describe Hancom behavior only; the user's document paths, file names, and content stay out of them.
5. Tell the user which skill files changed; they live in the skills repository and stay uncommitted until the user says otherwise.

Recording is done when the probe file exists, its JSON reports `ok: true` on the current build, and the entry names that build.

Re-verifying on a new build (machine setup step 3): run every probe in `scripts/probes/`, append the build to entries whose observations still hold, and rewrite entries whose observations changed.

## Calling from PowerShell

- Most actions: `$set = $Hwp.HParameterSet.H<SetName>`, `$Hwp.HAction.GetDefault('<Action>', $set.HSet)`, set items through wrapper properties or `$set.HSet.SetItem('<Item>', value)`, then `$Hwp.HAction.Execute('<Action>', $set.HSet)`.
- `HSet` exposes no `Item` or `CreateItemArray` to PowerShell, and some wrappers lack properties for documented items (`HShapeObject` has no `ShapeType`); set those with `HSet.SetItem` and read results back from markup with `Read-HwpMarkup $Hwp` (from `hancom-session.ps1`, available to task scripts and probes).
- Array items need the action-object route; see TableCreate.
- verified: 11.0.0.9166, 2026-11-25 (all probes below)

## Entries

### AllReplace

- Call: `$set = $Hwp.HParameterSet.HFindReplace; $Hwp.HAction.GetDefault('AllReplace', $set.HSet)`; set `FindString`, `ReplaceString`, `IgnoreMessage = 1`, `Direction = 2` (whole document); then `$Hwp.HAction.Execute('AllReplace', $set.HSet)`.
- Observed: every occurrence is replaced regardless of cursor position. The return value follows the cursor, not the result: from the document start it returned `False` even after replacing; from the document end it returned `True`; with no occurrence it returned `False`. Confirm success by counting occurrences in `GetTextFile('TEXT','')` before and after.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/allreplace.ps1`
- Manual: `ParameterSetTable_2504` § 57 FindReplace (`Direction` 2 = whole document; `IgnoreMessage` suppresses message boxes).

### Text input and breaks (InsertText, BreakLine, BreakPara, BreakPage)

- Call: `HInsertText.Text` with `InsertText`; `$Hwp.HAction.Run('BreakLine' | 'BreakPara' | 'BreakPage')`.
- Observed: `BreakLine` puts `<LINEBREAK/>` inside the paragraph, which `GetTextFile('TEXT','')` drops (the two lines run together). `BreakPara` starts a paragraph that inherits the current char and paragraph shape. `BreakPage` starts a paragraph marked `PageBreak="true"`. Each `Run` returned `True`.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/text-input.ps1`
- Manual: `ActionTable_2504` (InsertText, BreakLine, BreakPara, BreakPage); `ParameterSetTable_2504` § 72 InsertText.

### PageSetup

- Call: `HSecDef`; set `PageDef.PaperWidth`, `PaperHeight`, `LeftMargin`, `RightMargin`, `TopMargin`, `BottomMargin`, `HeaderLen`, `FooterLen`, `GutterLen` (HWPUNIT, 1 mm = 283.465); `HSet.SetItem('ApplyClass', 24)`, `HSet.SetItem('ApplyTo', 3)` (whole document).
- Observed: `PAGEDEF`/`PAGEMARGIN` hold exactly the values set. A blank document starts with left/right 8504, top 5668, bottom 4252, header/footer 4252.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/page-setup.ps1`
- Manual: `ActionTable_2504` PageSetup (SecDef); `ParameterSetTable_2504` § 87 PageDef, § 102 SecDef.

### PageNumPos, PageHiding

- Call: `HPageNumPos` with `DrawPos = 5` (bottom centre), `NumberFormat = 0`, `SideChar = [int][char]'-'`; `HPageHiding.Fields = 0x20` (page number) with the caret on the page to hide.
- Observed: `<PAGENUM FormatType="Digit" Pos="BottomCenter" SideChar="-"/>`, rendered as `- n -`; `<PAGEHIDING HidePageNum="true"/>` hides the number on that page.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/page-number.ps1`
- Manual: `ParameterSetTable_2504` § 88 PageHiding, § 90 PageNumPos.

### CharShape

- Call: `HCharShape`; for each language (`Hangul`, `Latin`, `Hanja`, `Japanese`, `Other`, `Symbol`, `User`) `HSet.SetItem` `FaceName<Lang>`, `FontType<Lang>`, `Ratio<Lang>`, `Spacing<Lang>`; `Height` (HWPUNIT, 100 = 1 pt), `Bold`, `TextColor` (0x00BBGGRR); execute before typing.
- Observed: applies to text typed afterwards and carries into new paragraphs. `FontType` 1 records a TrueType font (`Type="ttf"` in the font list), 2 a Hancom HFT font (`Type="hft"`, e.g. HCI Poppy); copy the type an inspected document shows. `TextColor` is stored as the same integer.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/char-shape.ps1`
- Manual: `ParameterSetTable_2504` § 13 CharShape.

### ParagraphShape

- Call: `HParaShape`: `AlignType` (0 justify, 1 left, 2 right, 3 centre, 4 distribute, 5 divide), `LineSpacingType = 0` with `LineSpacing` in percent, `LeftMargin`, `RightMargin`, `Indentation`, `PrevSpacing`, `NextSpacing`, `Condense`, `WidowOrphan`, `BreakNonLatinWord`, `LineWrap`.
- Observed: margins and spacing (the manual's "URC") are stored unchanged, as the same numbers `PARAMARGIN` shows, so values from an inspected document copy across directly. `LineWrap`, which the manual mislabels as a line-height flag: 0 = `Break`, 1 = `Squeeze` (letter spacing tightens to keep the paragraph on one line), 2 = shown empty in HWPML. In the 한글 2020 UI, `Squeeze` is "한 줄로 입력" on the [확장] tab of 문단 모양, stored in `PARASHAPE`. The [셀] tab of 표/셀 속성 has an option with the same name that is stored on the cell's `PARALIST` instead (see TablePropertyDialog). Copy whichever one the inspected document uses. Applies to the caret paragraph and carries into following ones.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/para-shape.ps1`
- Manual: `ParameterSetTable_2504` § 91 ParaShape.

### TableCreate (with TableLowerCell, MoveDocEnd)

- Call: arrays need the action-object route: `$action = $Hwp.CreateAction('TableCreate'); $set = $action.CreateSet(); $action.GetDefault($set)`; `SetItem` `Rows`, `Cols`, `WidthType = 2`, `HeightType = 1`; `$set.CreateItemArray('ColWidth', n)` and `'RowHeight'`, each filled with `.SetItem(index, value)`; `$table = $set.CreateItemSet('TableProperties', 'Table')` with `TreatAsChar = 1`, `CellMargin<Side>`, `OutsideMargin<Side>`; `$action.Execute($set)`. Through `HParameterSet.HTableCreation`, `CreateItemArray` returns nothing and the arrays cannot be filled.
- Observed: cell width = `ColWidth` + 2 × `CellMargin` (stored as the table's `INSIDEMARGIN`); cell height = `RowHeight` + 2 × the same margin. The caret starts in the first cell; `TableLowerCell` moves down; `MoveDocEnd` leaves the table into an empty paragraph that table creation adds after it. New cells store their own 510/141 `CELLMARGIN` with `HasMargin="false"`. Cells normally follow the table's common inner margin; "안 여백 지정" (`HasMargin`) is turned on only for a cell whose margin should differ from it, and only then is `CELLMARGIN` used (changing `CELLMARGIN` alone left the render unchanged). A second table in the same document received the previous table's outside margin instead of the requested one; set it again with TablePropertyDialog.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/table.ps1`
- Manual: `ActionTable_2504` (TableCreate, TableLowerCell, MoveDocEnd); `ParameterSetTable_2504` § 115 Table, § 116 TableCreation; `HwpAutomation_2504` CreateItemArray.

### TablePropertyDialog

- Call, caret inside the table: `$set = $Hwp.HParameterSet.HShapeObject; $Hwp.HAction.GetDefault('TablePropertyDialog', $set.HSet)`. Table outside margin: `HSet.SetItem('OutsideMargin<Side>', value)`. Margins of the caret cell: `HSet.SetItem('ShapeType', 3)`, `HSet.SetItem('ShapeCellSize', 0)`, `ShapeTableCell.HasMargin = 0`, `ShapeTableCell.Margin<Side> = value`. Then `Execute`.
  The cell option "한 줄로 입력": `HSet.SetItem('ShapeType', 3)` and `ShapeTableCell.LineWrap = 1` or `2`.
- Observed: the first form changes that table's `OUTSIDEMARGIN`; the second changes only the caret cell's `CELLMARGIN`, with `HasMargin` staying `false`, so the cell keeps following the table's inner margin; set `HasMargin = 1` only when the cell's margin should differ from the table's. `ShapeTableCell.LineWrap` sets the caret cell's `PARALIST` `LineWrap`: 1 = `Squeeze`, 2 = `Keep`; the cell's paragraph shapes stay `Break`. The manual lists no `ShapeType` values; 3 is the cell case observed here.
- verified: 11.0.0.9166, 2026-11-25
- Probes: `scripts/probes/cell-margin.ps1`, `scripts/probes/table.ps1`
- Manual: `ActionTable_2504` TablePropertyDialog (ShapeObject); `ParameterSetTable_2504` § 105 ShapeObject (`ShapeTableCell`, `ShapeType`), § 10 Cell, § 77 ListProperties (`LineWrap`: 0 normal, 1 no wrap, 2 keep one line by adjusting spacing; HWPML names 1 `Squeeze` and 2 `Keep`, so the manual's order and the markup names disagree — confirm by rendering before relying on either). UI: 한글 2020 help, 표/셀 속성: 셀 and 문단 모양: 확장 (see api-sources.md).

### CellBorderFill

- Call, caret in a cell (no block selection needed): `HCellBorderFill`; `HSet.SetItem` `BorderType<Side>` (line type code), `BorderWidth<Side>` (width code), colours `BorderCorlorLeft` (spelled as in the manual), `BorderColorRight`, `BorderColorTop`, `BorderColorBottom`; solid fill `FillAttr.Type = 1`, `FillAttr.WinBrushFaceColor`, `FillAttr.WinBrushHatchColor = 0`, `FillAttr.WinBrushFaceStyle = -1`; no fill `FillAttr.Type = 0`.
- Observed: applies to the caret cell. The left colour follows `BorderCorlorLeft`; `BorderColorLeft` is accepted and ignored. Width codes 1 = 0.12 mm and 9 = 0.7 mm appear as those widths in `BORDERFILL`.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/cell-border-fill.ps1`
- Manual: `ParameterSetTable_2504` § 5 BorderFill, § 11 CellBorderFill, § 32 DrawFillAttr, "기타 정보" 1) 선 종류, 2) 선 굵기.
