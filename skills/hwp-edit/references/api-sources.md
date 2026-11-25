# Hancom automation API sources

Where facts about Hancom actions, parameter sets, and COM members come from, and which source wins when they disagree. Sources checked 2026-11-25.

## Precedence

1. **Live probe** on the installed Hancom: an owned process (dot-source `scripts/hancom-session.ps1`) working on a disposable copy. Only a probe proves behavior.
2. **Installed type library**: exact COM method/property names and argument types for the installed build. It lists no action IDs and no valid values.
3. **Official 2504 manuals**: action IDs, parameter-set items, value meanings. They name no 한글 version, and the installed build can behave in ways they do not describe; on 한글 2020, for example, `AllReplace` returned `False` after a successful replacement ([native-edit.md](native-edit.md)).
4. **Older unversioned manuals**: background only.

## Version policy

Work against one Hancom build per machine: the one `HWPFrame.HwpObject` launches. Tag each verified fact with that build (`verified: 11.0.0.9166, 2026-11-25`). A fact verified on another build counts as unverified here until a probe re-confirms it. Other builds installed on the same machine stay out of scope.

Find the build COM launches (read-only; a 32-bit Hancom registers its server under `WOW6432Node`):

```powershell
$clsid = (Get-ItemProperty 'Registry::HKEY_CLASSES_ROOT\HWPFrame.HwpObject\CLSID').'(default)'
$server = foreach ($view in 'CLSID','WOW6432Node\CLSID') {
    $key = "Registry::HKEY_CLASSES_ROOT\$view\$clsid\LocalServer32"
    if (Test-Path $key) { (Get-ItemProperty $key).'(default)'; break }
}
$exe = $server -replace '\s+-Automation$',''
(Get-Item $exe).VersionInfo.FileVersion
```

## Official manuals

The official page https://developer.hancom.com/hwpautomation (section "1. API 매뉴얼") links to files in the GitHub repository `hancom-io/devcenter-archive`, whose README describes it as the store for files the Hancom Developer Center provides. Download base: `https://github.com/hancom-io/devcenter-archive/raw/main/hwp-automation/<file>`.

| File | Covers | On official page | Git blob SHA-1 |
| --- | --- | --- | --- |
| `ActionTable_2504.pdf` | Action IDs, their parameter sets, descriptions | yes | `162e5e70f812515d9a90e3fd888f328e6f80e26f` |
| `ParameterSetTable_2504.pdf` | Parameter-set items, types, values | yes | `50ff092e81c81f8bba54a17d98b6aa4d909e6f87` |
| `HwpAutomation_2504.pdf` | `HwpObject` methods and properties | yes | `9985830b299ee1958ed41ab89e57fb8fc531bca7` |
| `한글오토메이션EventHandler추가_2504.pdf` | Automation events | yes | `a46b8a88c844ff2a638b42645ea8fc8334c2e42d` |
| `HwpAutomation.pdf` | Older object manual | archive only | `aba0ead7e0ef6f2f76fab3a8e849bbb86d211553` |
| `ActionObject.pdf` | Action object | archive only | `20c091c89aebe2867110652dc16e0c0ad1ce8870` |
| `ParameterSetObject.pdf` | Parameter-set object | archive only | `6e6618964229b4350a62c54b72576186a591d1ac` |

The 2504 files were uploaded 2025-04-21; nothing newer than 2504 existed on 2026-11-25. The security module ZIP is on the same page; see [security-module.md](security-module.md).

Check a copy: `git hash-object --no-filters -- <file>` must equal the blob SHA above. Check for newer releases with `https://api.github.com/repos/hancom-io/devcenter-archive/contents/hwp-automation` (lists name, size, blob SHA).

Terms: the page allows free personal non-commercial use and requires a Hancom license for commercial use. Keep the manuals outside this skill and its repository; ask the user before downloading them.

This skill is shared across machines, so it names files, never folders on a particular machine. To use a copy the user already has, ask where it is or search by file name, and accept it only when its blob SHA matches.

## Installed type library

The type library registered as `{7D2B6F3C-1D95-4E0C-BF5A-5EE564186FBC}` (HwpObject 1.0) gives the installed build's interfaces, including parameter-set object properties such as `HFindReplace.FindString`. Its path is under `HKEY_CLASSES_ROOT\TypeLib\{7D2B6F3C-1D95-4E0C-BF5A-5EE564186FBC}\1.0\0\win32`; `HwpAutomation.tlb` sits in the same `Bin` folder. Read it with `LoadTypeLibEx(path, REGKIND_NONE)`, which neither starts Hancom nor registers anything.
