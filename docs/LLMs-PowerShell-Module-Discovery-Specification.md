# LLMs PowerShell Module Discovery Specification

## Purpose

Use this specification as an implementation prompt for reorganizing the
`The-Running-Dev/LLMs` repository. The goal is to make its intended PowerShell
interface discoverable by `SubZeroDev.ContainerPSGenerator` through simple
Version 1 conventions.

This is a structure-and-metadata change. Do not redesign the setup workflow,
change installer behavior, or expose infrastructure scripts as public commands.

## Current repository inventory

The repository currently contains three distinct kinds of PowerShell code.

### Existing public module

`setup/modules/ProjectSetup.psm1` explicitly exports these functions:

- `New-ProjectStructure`
- `New-ProjectFile`
- `New-Gitignore`
- `New-EnvExample`
- `New-ReadmeFile`
- `New-ArchitectureFile`
- `New-AdtTemplate`
- `New-ClaudeInstructions`
- `New-AgentsInstructions`
- `Initialize-ProjectGit`
- `Invoke-LanguageStarter`
- `Test-ProjectBuildable`
- `Test-ProjectTestable`
- `New-ProjectInitialCommit`

These exports are the authoritative public API of the existing module.

`setup/modules/Common.ps1` contains shared implementation helpers. Its
functions are private and must not be exported.

### Independently runnable component scripts

These scripts are beneath a directory named `scripts` and are candidates for
standalone discovery:

```text
setup/scripts/starters/setup-starter-node.ps1
setup/scripts/starters/setup-starter-python.ps1
setup/scripts/workstation/install-claude-mem.ps1
setup/scripts/workstation/install-claude-memory.ps1
setup/scripts/workstation/install-database-mcp.ps1
setup/scripts/workstation/install-filesystem-mcp.ps1
setup/scripts/workstation/install-github-mcp.ps1
setup/scripts/workstation/install-graphify.ps1
setup/scripts/workstation/install-playwright-mcp.ps1
```

All nine scripts currently parse successfully as PowerShell.

### Orchestration and infrastructure scripts

The following are not standalone public module commands:

- `container-entrypoint.ps1`
- `setup/setup.ps1`
- `setup/setup-workstation.ps1`
- `setup/setup-windows.ps1`
- `setup/setup-ubuntu.ps1`
- `setup/setup-macos.ps1`
- `setup/setup-docs.ps1`
- `setup/setup-project.ps1`
- `setup/docs-local.ps1`
- `setup/docs-workflow-local.ps1`

They coordinate other components, select a platform, build documentation, or
implement the container entrypoint. Keep them outside directories named
`scripts` and do not export them from the module manifest.

## Required target structure

Keep the existing source locations. Add a module manifest beside the existing
module:

```text
setup/
├── modules/
│   ├── Common.ps1
│   ├── ProjectSetup.psm1
│   └── ProjectSetup.psd1
├── scripts/
│   ├── starters/
│   │   ├── setup-starter-node.ps1
│   │   └── setup-starter-python.ps1
│   └── workstation/
│       └── install-*.ps1
└── setup*.ps1
```

Do not move `container-entrypoint.ps1` or any `setup/setup*.ps1` file into
`setup/scripts`.

## ProjectSetup manifest requirements

Create `setup/modules/ProjectSetup.psd1` with:

- `RootModule = 'ProjectSetup.psm1'`
- a valid semantic `ModuleVersion`
- a stable `GUID`
- non-empty `Author`, `CompanyName`, `Description`, and `PowerShellVersion`
- `FunctionsToExport` containing exactly the 14 functions already passed to
  `Export-ModuleMember`
- `CmdletsToExport = @()`
- `VariablesToExport = @()`
- `AliasesToExport = @()`
- useful `PrivateData.PSData` fields when repository URLs and tags are known

The manifest must not export wildcard functions.

The export list in `ProjectSetup.psd1` and the list passed to
`Export-ModuleMember` in `ProjectSetup.psm1` must match exactly.

`Common.ps1` remains private implementation. Do not add it to
`FunctionsToExport`, and do not turn its helper functions into public commands.

## Standalone script requirements

Every `.ps1` file beneath `setup/scripts` is treated as independently runnable.
For each script:

1. It must parse without errors under supported PowerShell versions.
2. It must declare a script-level `param` block.
3. It should use `[CmdletBinding()]`; use
   `[CmdletBinding(SupportsShouldProcess)]` when it changes machine or repository
   state.
4. It must contain comment-based help with at least:
   - `.SYNOPSIS`
   - `.DESCRIPTION`
   - one `.PARAMETER` entry for every declared parameter
   - at least one `.EXAMPLE`
5. Parameters must use explicit PowerShell types.
6. Mandatory parameters must use `[Parameter(Mandatory)]`.
7. Closed sets must use `ValidateSet` where practical.
8. A script must not rely on being dot-sourced by its caller.
9. Shared implementation belongs in `setup/modules/Common.ps1` or another
   private module, not in duplicated script-local helper functions.

Do not rename scripts merely to manufacture PowerShell `Verb-Noun` filenames.
The discovery tool is responsible for deriving a valid generated command name
from the path and filename. The source path remains the stable identity.

## Discovery contract

The repository should be compatible with this simple discovery behavior:

1. Find `.psm1` files beneath directories named `modules`.
2. If a sibling `.psd1` exists, treat `FunctionsToExport` as the public API.
3. Otherwise, fall back to a literal `Export-ModuleMember -Function` list.
4. Find `.ps1` files beneath directories named `scripts`.
5. Inspect their script-level parameters and comment-based help without
   executing or importing repository code.
6. Ignore helper `.ps1` files beneath `modules`.
7. Ignore `.ps1` files outside `scripts`, including container entrypoints and
   setup orchestrators.
8. Do not recurse into `.git`, generated output, dependency directories, or Git
   submodules such as `docs-template`.

The scanner must not infer public commands from every function definition in a
module. Only explicit exports are public.

## Compatibility constraints

- Preserve all existing script paths used by `setup/setup-workstation.ps1` and
  `ProjectSetup.psm1`.
- Preserve all existing function names and parameter contracts.
- Preserve Windows, Linux, and macOS setup dispatch.
- Preserve `SupportsShouldProcess` and current `-WhatIf` behavior.
- Do not execute installers, initialize Git repositories, modify user
  configuration, or start containers during validation.
- Do not add secrets, tokens, `.env` contents, or machine-specific paths.
- Do not modify the `docs-template` submodule.

## Validation commands

Run these checks from the LLMs repository root:

```powershell
$errors = @()
Get-ChildItem ./setup/scripts -Recurse -File -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    $errors += $parseErrors
}
if ($errors.Count -gt 0) { throw ($errors | Out-String) }

$module = Test-ModuleManifest ./setup/modules/ProjectSetup.psd1 -ErrorAction Stop
Import-Module ./setup/modules/ProjectSetup.psd1 -Force

$expected = @(
    'New-ProjectStructure'
    'New-ProjectFile'
    'New-Gitignore'
    'New-EnvExample'
    'New-ReadmeFile'
    'New-ArchitectureFile'
    'New-AdtTemplate'
    'New-ClaudeInstructions'
    'New-AgentsInstructions'
    'Initialize-ProjectGit'
    'Invoke-LanguageStarter'
    'Test-ProjectBuildable'
    'Test-ProjectTestable'
    'New-ProjectInitialCommit'
) | Sort-Object

$actual = Get-Command -Module $module.Name |
    Where-Object CommandType -eq Function |
    Select-Object -ExpandProperty Name |
    Sort-Object

if (Compare-Object $expected $actual) {
    throw 'ProjectSetup module exports do not match the required public API.'
}
```

Validation must inspect scripts and module metadata only. It must not invoke any
setup or installer operation.

## Acceptance criteria

- `setup/modules/ProjectSetup.psd1` exists and passes `Test-ModuleManifest`.
- Importing the manifest exports exactly the existing 14 public functions.
- `Common.ps1` helpers remain private.
- Every script under `setup/scripts` has a parseable script-level parameter
  block and complete comment-based help.
- Orchestration and container infrastructure scripts remain outside
  `setup/scripts`.
- Existing setup commands and paths continue to work.
- No installer or setup action is executed by validation.
- No files inside the `docs-template` submodule are changed.

## Implementation instruction for an LLM

Inspect the current repository before editing. Apply the smallest changes that
satisfy this specification. Preserve behavior and paths. Create the
`ProjectSetup.psd1` manifest, improve missing metadata/help on scripts beneath
`setup/scripts`, and add non-invasive validation tests. Do not reorganize
unrelated code, expose private helpers, or execute setup scripts. Report the
exact files changed and validation results.
