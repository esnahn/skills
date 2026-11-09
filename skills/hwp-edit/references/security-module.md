# Hancom security module setup

The skill contains no Hancom DLL or ZIP. Download the security module from the official page and retain the accompanying notices/instructions:

https://developer.hancom.com/hwpautomation

Choose **보안모듈(Automation).zip**, extract it, and find `FilePathCheckerModuleExample.dll`. The page explains the current-user registry entry and the `RegisterModule` call. Follow Hancom's usage/licensing terms; downloading from the official source is not a grant of additional redistribution or commercial rights.

## Check the current registration

```powershell
pwsh.exe -NoProfile -STA -File "<skill>/scripts/setup-security-module.ps1" -Mode Check
```

This only reads the registry, file existence, and hash. It does not start Hancom, copy files, or change settings. In a sandbox the registry read may need the appropriate execution permission; do not interpret access denied as a missing module.

## Explicit setup from a user-downloaded DLL

Open Hancom windows may stay open; the helper tests the module in its own separate Hancom process and closes only that one. Preview the operation:

```powershell
pwsh.exe -NoProfile -STA -File "<skill>/scripts/setup-security-module.ps1" -Mode Install -ModulePath "C:\downloads\security-module\FilePathCheckerModuleExample.dll" -WhatIf
```

To install, execute the same command without `-WhatIf`. Run this only when the user requests module setup/migration; ordinary document editing does not implicitly authorize registry changes.

The helper verifies the known DLL SHA-256, copies it into a versioned directory under `%LOCALAPPDATA%\Hancom\HwpAutomation\`, sets the single named current-user registry value, and checks Hancom's `RegisterModule` return value. It does not delete the old DLL, alter unrelated settings, use regsvr32, or install into the skill/Git directory. A registration/COM-check failure restores the prior named registry value; the copied DLL is retained for diagnosis. An unsuccessful rollback is reported explicitly.

Known DLL SHA-256 (the DLL, not the ZIP):

```text
9AC5B97C47AC8AED1E8BCA27A3EEF39411361D8F68C262509F0C40A8F9D21BB6
```

This pin matches the installed DLL checked during setup-helper validation. The current official ZIP has not been freshly downloaded and independently hashed. If an official newer DLL differs, stop and verify the new release before updating the pin; do not silently skip validation.

## Manual registration alternative

Keep the downloaded DLL in a stable folder outside a disposable repository. Register:

- Key: `HKEY_CURRENT_USER\Software\HNC\HwpAutomation\Modules`
- Value name: `FilePathCheckerModuleExample`
- Type: `REG_SZ`
- Data: the DLL's full absolute path

The edit runner calls `RegisterModule('FilePathCheckDLL','FilePathCheckerModuleExample')` before opening a file. Installation of Hancom itself is separate. Keep the DLL at its registered path.

Before deleting or moving any folder containing the registered DLL, migrate the module to a stable location and verify registration. Merely adding this guide or helper does not migrate an existing registration.
