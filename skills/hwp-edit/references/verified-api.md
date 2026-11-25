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
4. Add or update the entry below: how to call it, what was observed (including surprises), `verified: <build>, <date>`, the probe file, the manual sections consulted, and the UI name with its menu path and shortcut from the installed help (api-sources.md), or "none (COM only)". Entries and probe files describe Hancom behavior only; the user's document paths, file names, and content stay out of them.
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
- UI: 찾아 바꾸기 [편집-찾아 바꾸기] (Ctrl+F2), 모두 바꾸기.

### Text input and breaks (InsertText, BreakLine, BreakPara, BreakPage, special spaces)

- Call: `HInsertText.Text` with `InsertText`; `$Hwp.HAction.Run('BreakLine' | 'BreakPara' | 'BreakPage' | 'InsertFixedWidthSpace' | 'InsertNonBreakingSpace')`.
- Observed: `BreakLine` puts `<LINEBREAK/>` inside the paragraph, which `GetTextFile('TEXT','')` drops (the two lines run together). `BreakPara` starts a paragraph that inherits the current char and paragraph shape. `BreakPage` starts a paragraph marked `PageBreak="true"`. `InsertFixedWidthSpace` and `InsertNonBreakingSpace` put `<FWSPACE/>` and `<NBSPACE/>` into the text. Each `Run` returned `True`.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/text-input.ps1`
- Manual: `ActionTable_2504` (InsertText, BreakLine, BreakPara, BreakPage); `ParameterSetTable_2504` § 72 InsertText.
- UI: typing; Enter (문단 나누기); Shift+Enter (강제 줄 나눔); 쪽 나누기 [쪽-쪽 나누기] (Ctrl+Enter); 고정폭 빈칸 (Alt+Space); 묶음 빈칸 (Ctrl+Alt+Space).

### PageSetup

- Call: `HSecDef`; set `PageDef.PaperWidth`, `PaperHeight`, `LeftMargin`, `RightMargin`, `TopMargin`, `BottomMargin`, `HeaderLen`, `FooterLen`, `GutterLen` (HWPUNIT, 1 mm = 283.465); `HSet.SetItem('ApplyClass', 24)`, `HSet.SetItem('ApplyTo', 3)` (whole document).
- Observed: `PAGEDEF`/`PAGEMARGIN` hold exactly the values set. A blank document starts with left/right 8504, top 5668, bottom 4252, header/footer 4252.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/page-setup.ps1`
- Manual: `ActionTable_2504` PageSetup (SecDef); `ParameterSetTable_2504` § 87 PageDef, § 102 SecDef.
- UI: 편집 용지 [파일-편집 용지] (F7), [기본] tab: 용지 종류, 용지 방향, 용지 여백.

### PageNumPos, PageHiding

- Call: `HPageNumPos` with `DrawPos = 5` (bottom centre), `NumberFormat = 0`, `SideChar = [int][char]'-'`; `HPageHiding.Fields = 0x20` (page number) with the caret on the page to hide.
- Observed: `<PAGENUM FormatType="Digit" Pos="BottomCenter" SideChar="-"/>`, rendered as `- n -`; `<PAGEHIDING HidePageNum="true"/>` hides the number on that page.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/page-number.ps1`
- Manual: `ParameterSetTable_2504` § 88 PageHiding, § 90 PageNumPos.
- UI: 쪽 번호 매기기 [쪽-쪽 번호 매기기] (Ctrl+N,P); 감추기 [쪽-감추기] (Ctrl+N,S).

### CharShape

- Call: `HCharShape`; for each language (`Hangul`, `Latin`, `Hanja`, `Japanese`, `Other`, `Symbol`, `User`) `HSet.SetItem` `FaceName<Lang>`, `FontType<Lang>`, `Ratio<Lang>`, `Spacing<Lang>`, `Size<Lang>` (relative size, `RELSIZE`), `Offset<Lang>` (`CHAROFFSET`); `Height` (HWPUNIT, 100 = 1 pt), `Bold`, `Italic`, `UnderlineType` (1 bottom, 2 centre, 3 top) with `UnderlineShape = 0` (solid) and `UnderlineColor`, `SuperScript`, `SubScript`, `TextColor` (0x00BBGGRR); execute before typing, or with a block selected (see Selecting and deleting ranges) to change existing text.
- Observed: applies to text typed afterwards and carries into new paragraphs. On a selected block, `Execute` applies only the items set and splits runs at the block's edges: `Bold` on three letters made one bold run, `SuperScript` on one letter one superscript run, and `Spacing<Lang>` over a block holding normal, bold and superscript runs changed the spacing of all three and kept bold and superscript. `FontType` 1 records a TrueType font (`Type="ttf"` in the font list), 2 a Hancom HFT font (`Type="hft"`, e.g. HCI Poppy); copy the type an inspected document shows. `TextColor` is stored as the same integer. Each of the items above shows up as the matching markup (`<ITALIC/>`, `<UNDERLINE Shape="Solid" Type="Bottom"/>`, `<SUPERSCRIPT/>`, `RELSIZE`, `CHAROFFSET`). Some downloaded documents carry `<STRIKEOUT Type="Continuous" Shape="3D"/>` on every shape and render no strikeout; a blank document's shapes carry none, so leave it unset when rebuilding.
- verified: 11.0.0.9166, 2026-11-25; on a block 2026-11-26
- Probes: `scripts/probes/char-shape.ps1`, `scripts/probes/char-shape-selection.ps1`
- Manual: `ParameterSetTable_2504` § 13 CharShape.
- UI: 글자 모양 [서식-글자 모양] (Alt+L); [기본] tab: 글꼴, 크기, 상대 크기 (`Size<Lang>`), 장평 (`Ratio`), 자간 (`Spacing`), 글자 위치 (`Offset`), 진하게, 기울임, 밑줄, 글자 색; [확장] tab: 밑줄 모양. On a block: 진하게 (Ctrl+B, Alt+Shift+B), 위 첨자 (Alt+Shift+P).

### ParagraphShape

- Call: `HParaShape`: `AlignType` (0 justify, 1 left, 2 right, 3 centre, 4 distribute, 5 divide), `LineSpacingType = 0` with `LineSpacing` in percent, `LeftMargin`, `RightMargin`, `Indentation`, `PrevSpacing`, `NextSpacing`, `Condense`, `WidowOrphan`, `BreakNonLatinWord`, `LineWrap`.
- Observed: margins and spacing (the manual's "URC") are stored unchanged, as the same numbers `PARAMARGIN` shows, so values from an inspected document copy across directly. `LineWrap`, which the manual mislabels as a line-height flag: 0 = `Break`, 1 = `Squeeze` (letter spacing tightens to keep the paragraph on one line), 2 = shown empty in HWPML. In the 한글 2020 UI, `Squeeze` is "한 줄로 입력" on the [확장] tab of 문단 모양, stored in `PARASHAPE`. The [셀] tab of 표/셀 속성 has an option with the same name that is stored on the cell's `PARALIST` instead (see TablePropertyDialog). Copy whichever one the inspected document uses. A negative `Indentation` is a hanging indent and is stored unchanged (`Indent="-3964"`). `PutBullet` sets `HeadingType` 3 (bullet); `HeadingType = 0` removes a bullet or number heading. `BreakNonLatinWord` 1 is stored as `true` (Korean words may split across lines) and 0 as `false` (lines break between words, and justified lines spread the spaces instead). Applies to the caret paragraph and carries into following ones.
- verified: 11.0.0.9166, 2026-11-26
- Probe: `scripts/probes/para-shape.ps1`
- Manual: `ParameterSetTable_2504` § 91 ParaShape.
- UI: 문단 모양 [서식-문단 모양] (Alt+T); [기본] tab: 정렬 방식, 여백, 첫 줄 들여쓰기/내어쓰기 (`Indentation`), 간격 (줄 간격, 문단 위/아래), 줄 나눔 기준 한글 단위 글자 (1) / 어절 (0) (`BreakNonLatinWord`), 최소 공백 (`Condense`); [확장] tab: 외톨이줄 보호, 한 줄로 입력 (`LineWrap`). Bullets: 글머리표 적용/해제 [서식-글머리표 적용/해제] (Ctrl+Shift+Delete).

### TableCreate (with TableLowerCell, MoveDocEnd)

- Call: arrays need the action-object route: `$action = $Hwp.CreateAction('TableCreate'); $set = $action.CreateSet(); $action.GetDefault($set)`; `SetItem` `Rows`, `Cols`, `WidthType = 2`, `HeightType = 1`; `$set.CreateItemArray('ColWidth', n)` and `'RowHeight'`, each filled with `.SetItem(index, value)`; `$table = $set.CreateItemSet('TableProperties', 'Table')` with `TreatAsChar = 1`, `CellMargin<Side>`, `OutsideMargin<Side>`; `$action.Execute($set)`. Through `HParameterSet.HTableCreation`, `CreateItemArray` returns nothing and the arrays cannot be filled.
- Observed: cell width = `ColWidth` + 2 × `CellMargin` (stored as the table's `INSIDEMARGIN`); cell height = `RowHeight` + 2 × the same margin. The caret starts in the first cell; `TableLowerCell` moves down; `MoveDocEnd` leaves the table into an empty paragraph that table creation adds after it. New cells store their own 510/141 `CELLMARGIN` with `HasMargin="false"`. Cells normally follow the table's common inner margin; "안 여백 지정" (`HasMargin`) is turned on only for a cell whose margin should differ from it, and only then is `CELLMARGIN` used (changing `CELLMARGIN` alone left the render unchanged). A second table in the same document received the previous table's outside margin instead of the requested one; set it again with TablePropertyDialog.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/table.ps1`
- Manual: `ActionTable_2504` (TableCreate, TableLowerCell, MoveDocEnd); `ParameterSetTable_2504` § 115 Table, § 116 TableCreation; `HwpAutomation_2504` CreateItemArray.
- UI: 표 만들기 [입력-표-표 만들기] (Ctrl+N,T), with 글자처럼 취급 (`TreatAsChar`).

### TablePropertyDialog

- Call, caret inside the table: `$set = $Hwp.HParameterSet.HShapeObject; $Hwp.HAction.GetDefault('TablePropertyDialog', $set.HSet)`. Table outside margin: `HSet.SetItem('OutsideMargin<Side>', value)`. Margins of the caret cell: `HSet.SetItem('ShapeType', 3)`, `HSet.SetItem('ShapeCellSize', 0)`, `ShapeTableCell.HasMargin = 0`, `ShapeTableCell.Margin<Side> = value`. Then `Execute`.
  The cell option "한 줄로 입력": `HSet.SetItem('ShapeType', 3)` and `ShapeTableCell.LineWrap = 1` or `2`.
- Observed: the first form changes that table's `OUTSIDEMARGIN`; the second changes only the caret cell's `CELLMARGIN`, with `HasMargin` staying `false`, so the cell keeps following the table's inner margin; set `HasMargin = 1` only when the cell's margin should differ from the table's. `ShapeTableCell.LineWrap` sets the caret cell's `PARALIST` `LineWrap`: 1 = `Squeeze`, 2 = `Keep`; the cell's paragraph shapes stay `Break`. The manual lists no `ShapeType` values; 3 is the cell case observed here.
- verified: 11.0.0.9166, 2026-11-25
- Probes: `scripts/probes/cell-margin.ps1`, `scripts/probes/table.ps1`
- Manual: `ActionTable_2504` TablePropertyDialog (ShapeObject); `ParameterSetTable_2504` § 105 ShapeObject (`ShapeTableCell`, `ShapeType`), § 10 Cell, § 77 ListProperties (`LineWrap`: 0 normal, 1 no wrap, 2 keep one line by adjusting spacing; HWPML names 1 `Squeeze` and 2 `Keep`, so the manual's order and the markup names disagree — confirm by rendering before relying on either).
- UI: 표/셀 속성 [표 디자인-표/셀 속성] (P); [여백/캡션] tab: 바깥 여백 (`OutsideMargin`); [셀] tab: 안 여백 지정 (`HasMargin`, `Margin<Side>`), 한 줄로 입력 (`ShapeTableCell.LineWrap`).

### CellBorderFill

- Call, caret in a cell (no block selection needed): `HCellBorderFill`; `HSet.SetItem` `BorderType<Side>` (line type code), `BorderWidth<Side>` (width code), colours `BorderCorlorLeft` (spelled as in the manual), `BorderColorRight`, `BorderColorTop`, `BorderColorBottom`; solid fill `FillAttr.Type = 1`, `FillAttr.WinBrushFaceColor`, `FillAttr.WinBrushHatchColor = 0`, `FillAttr.WinBrushFaceStyle = -1`; no fill `FillAttr.Type = 0`.
- Observed: applies to the caret cell. The left colour follows `BorderCorlorLeft`; `BorderColorLeft` is accepted and ignored. Width codes 1 = 0.12 mm and 9 = 0.7 mm appear as those widths in `BORDERFILL`.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/cell-border-fill.ps1`
- Manual: `ParameterSetTable_2504` § 5 BorderFill, § 11 CellBorderFill, § 32 DrawFillAttr, "기타 정보" 1) 선 종류, 2) 선 굵기.
- UI: 셀 테두리/배경 [표 디자인-셀 테두리/배경], 각 셀마다 적용; [테두리] and [배경] tabs.

### Cell navigation and merging

- Call, caret in a table: first cell `Run('TableColPageUp')` then `Run('TableColBegin')`; moves `TableRightCell`, `TableLeftCell`, `TableLowerCell`, `TableUpperCell`; merge: caret in the block's top-left cell, `TableCellBlock`, `TableCellBlockExtend`, move to the bottom-right cell, `TableMergeCell`, then `Cancel`.
- Observed: `TableRightCell` walks grid positions row by row, wrapping to the next row, and returns `False` at the last cell. A merged cell is entered again on every row it spans (a 3-row merge collected text from three visits), so fill a merged table by simulating that walk and writing each cell on its first visit. Merging cells that hold text concatenates their text, so merge while the cells are empty; merging bottom-right spans first keeps the moves from the first cell regular.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/table-cells.ps1`
- Manual: `ActionTable_2504` (TableColPageUp, TableColBegin, TableRightCell, TableLeftCell, TableCellBlock, TableCellBlockExtend, TableMergeCell).
- UI: 셀 블록 (F5), 셀 블록 연장 (F5 twice); 셀 합치기 [표 디자인-셀 합치기] (M). The moves are ActionTable's 셀 이동 actions.

### SetCurFieldName (cell names)

- Call, caret in the cell: `$Hwp.SetCurFieldName('<name>', 1, '', '')` (option 1 = cell).
- Observed: the cell gets `Name="<name>"` in markup and appears in `GetFieldList(1, 1)` as `<name>{{0}}`.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/table-cells.ps1`
- Manual: `HwpAutomation_2504` SetCurFieldName, GetCurFieldName (`hwpFieldCell` = 1).
- UI: 표/셀 속성 [셀] tab, 필드 이름.

### TableDeleteRow

- Call, caret in the row: `Run('TableDeleteRow')`.
- Observed: deletes the caret's row (also with a single-cell block). With a block extended over two rows beside a merged cell it returned `False` and deleted nothing, so delete such rows one at a time and check `RowCount`. A merged cell loses the deleted rows from its span.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/table-cells.ps1`
- Manual: `ActionTable_2504` TableDeleteRow (TableDeleteLine); `ParameterSetTable_2504` § 117 TableDeleteLine.
- UI: 줄/칸 지우기 [표 디자인-줄/칸 지우기] (Alt+Delete).

### PutFieldText and MoveToField

- Call: `$Hwp.PutFieldText('<name>{{n}}', 'text')`; `$Hwp.MoveToField('<name>{{n}}', $true, $true, $false)` puts the caret at the start of the field without selecting.
- Observed: on a cell field, `PutFieldText` replaces all of the cell's paragraphs with one paragraph that keeps the shape of the cell's last paragraph (a left- then right-aligned cell came out right-aligned); reset the paragraph shape afterwards when the first and last differ. `MoveToField` returned `True` and is a dependable way into a named cell, from which `Table*Cell` moves reach unnamed neighbours.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/fields-and-ranges.ps1`
- Manual: `HwpAutomation_2504` PutFieldText, MoveToField.
- UI: none (COM only); the field is the cell's 필드 이름 (see SetCurFieldName).

### Selecting and deleting ranges

- Call: root-list paragraphs: `Run('MoveDocBegin')`, `$Hwp.SelectText(startPara, startPos, endPara, endPos)` (end position excluded), `Run('Delete')`. To the end of the document: caret at a paragraph start, `Run('MoveLeft')` to the previous paragraph's end, `Run('MoveSelDocEnd')`, `Run('Delete')`. A cell's contents: `Run('MoveListBegin')`, `Run('MoveSelListEnd')`, `Run('Delete')`, then type. Part of a paragraph: `SelectText(para, start, para, end)`, confirm the block with `[string]$Hwp.GetTextFile('TEXT', 'saveblock')` before acting on it, and drop it with `Run('Cancel')`.
- Observed: `SelectText(1, 0, 3, 0)` + `Delete` removed paragraphs 1–2 whole. `MoveLeft` at a paragraph start lands at the end of the previous paragraph, so deleting from there to the document end leaves no empty paragraph; deleting from the paragraph start and then `DeleteBack` left one behind on a real document. The cell sequence empties the cell and keeps its first character shape for the new text. Positions count each control as 8 (the section and column definitions at the start of a document's first paragraph put its first character at 16) and each inline element as 1 (고정폭 빈칸 `<FWSPACE/>`, 강제 줄 나눔 `<LINEBREAK/>`); `InnerText` of the markup skips those elements, so count them when computing positions from HWPML. `SelectText` returns `True` even when its positions select nothing; `saveblock` then returns empty text. Text typed after deleting part of a paragraph takes the shape of the character before the caret, not that of the deleted text. `saveblock` text kept curly quotes and 「」 intact.
- verified: 11.0.0.9166, 2026-11-25; within a paragraph 2026-11-26
- Probes: `scripts/probes/fields-and-ranges.ps1`, `scripts/probes/char-shape-selection.ps1`
- Manual: `HwpAutomation_2504` SelectText, GetTextFile (`saveblock`: the selected block only; not while an object is selected); `ActionTable_2504` (MoveSelDocEnd, MoveListBegin, MoveSelListEnd, Delete, MoveLeft, Cancel).
- UI: 블록 설정 (F3, or drag), then Delete; 블록 해제 (Esc).

### InsertPicture

- Call: `$ctrl = $Hwp.InsertPicture('<path>', $true, 0, $false, $false, 0, 0, 0)` (all eight arguments; width and height are whole millimetres), then `$props = $ctrl.Properties`, `SetItem('Width'|'Height', HWPUNIT)`, `SetItem('TreatAsChar', 1)`, `SetItem('OutsideMargin<Side>', value)`, `$ctrl.Properties = $props`.
- Observed: six arguments fail ("Cannot find an overload"). The control's `CtrlID` is `gso`. Real size follows the pixels at 96 dpi (200 px = 15000 HWPUNIT); the properties then set the exact `SIZE`. A picture whose markup shows an original size (`OriWidth`/`OriHeight`) different from `IMAGEDIM` or non-zero `XPos`/`YPos` was scaled or cropped in an earlier edit; inserting the same file at the same `SIZE` places it identically but resamples slightly differently (JPG logos differed only inside their boxes).
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/picture.ps1`
- Manual: `HwpAutomation_2504` InsertPicture; `ParameterSetTable_2504` § 105 ShapeObject.
- UI: 그림 [입력-그림] (Ctrl+N,I), then the size in the picture's properties.

### CreatePageImage

- Call: `$Hwp.CreatePageImage('<file>.bmp', pageIndex, dpi, 24, 'bmp')` after `Run('MoveDocEnd')`.
- Observed: on a freshly opened five-page press release with tables, pictures and a drawing object, pages 2–5 returned `False` until the caret had visited the document end; a plain 20-page document rendered every page either way. The Render runner therefore moves to the end first.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/page-image.ps1` (plain document; the failure needs a richer document to reproduce)
- Manual: `HwpAutomation_2504` CreatePageImage.
- UI: none (COM only).
