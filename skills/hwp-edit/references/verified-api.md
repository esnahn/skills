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

## Entries

### AllReplace

- Call: `$set = $Hwp.HParameterSet.HFindReplace; $Hwp.HAction.GetDefault('AllReplace', $set.HSet)`; set `FindString`, `ReplaceString`, `IgnoreMessage = 1`, `Direction = 2` (whole document); then `$Hwp.HAction.Execute('AllReplace', $set.HSet)`.
- Observed: every occurrence is replaced regardless of cursor position. The return value follows the cursor, not the result: from the document start it returned `False` even after replacing; from the document end it returned `True`; with no occurrence it returned `False`. Confirm success by counting occurrences in `GetTextFile('TEXT','')` before and after.
- verified: 11.0.0.9166, 2026-11-25
- Probe: `scripts/probes/allreplace.ps1`
- Manual: `ParameterSetTable_2504` § 57 FindReplace (`Direction` 2 = whole document; `IgnoreMessage` suppresses message boxes).
