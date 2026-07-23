# SubZeroDev.ContainerPSGenerator

[![Test](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/test.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/test.yml)

SubZeroDev.ContainerPSGenerator is a PowerShell 7.4+ build tool for generating repository-specific PowerShell modules for containerized applications.

Repositories describe their public interface in a declarative PowerShell data file. During the normal repository build, the generator produces a complete, self-contained module that is embedded in the container image. Users can then install that module from the image and work with native PowerShell commands instead of assembling `docker run` invocations manually.

> **Status:** Version 1 specification and implementation are under active development.

## Goals

- Keep the repository as the single source of truth.
- Generate deterministic, self-contained PowerShell source code.
- Use native PowerShell types, validation, help, and completion.
- Separate build-time inspection and generation from runtime execution.
- Support extensibility through an ordered plugin pipeline.
- Provide a cross-platform experience on PowerShell 7.4+.

## Implemented so far

The current implementation supports the complete basic workflow from a repository specification to an installable generated module:

- Load PowerShell data-file specifications from the conventional or an explicit path.
- Validate module identity, container image references, commands, parameters, stable object IDs, mappings, validation rules, completion providers, help, and examples.
- Normalize specifications into a typed object model and deterministic JSON metadata.
- Generate importable module manifests, loaders, and public command source without a shared runtime dependency.
- Render native `ValidateSet`, `ValidateRange`, and `ValidatePattern` parameter attributes.
- Render static native PowerShell argument completion without restricting accepted values.
- Generate comment-based help and deterministic Markdown command references from synopsis, descriptions, parameter help, examples, and notes.
- Automatically discover pipeline plugins beside a specification, invoke all seven stages at defined build boundaries, and retain per-plugin execution diagnostics.
- Inspect root-level Dockerfile variants and persist ordered build-stage image, alias, and platform metadata.
- Inspect root-level Docker Compose files and persist ordered service image, build context, Dockerfile, and port metadata.
- Inspect .NET and Node project manifests while excluding generated and dependency directories.
- Inspect root README title, heading hierarchy, and fenced-code language metadata.
- Inspect PowerShell ASTs, GitHub Actions workflows, NUKE markers, JSON configuration schemas, and OpenAPI documents.
- Translate bound parameters into ordered `docker run --rm` arguments for command arguments, environment variables, bind mounts, named volumes, ports, working directories, devices, GPUs, resource limits, secrets, and generic runtime options.
- Preview generated Docker invocations through `-WhatIf` and report missing-runtime or non-zero-exit failures.
- Install `/PSModule` from a container image through a staged, manifest-validated, replace-safe workflow with `-Force` and `-WhatIf` support.
- Test another local repository through `build/Test-LocalRepository.ps1` and reproduce the Linux CI job locally with `build/Invoke-CI.ps1` and `act`.
- Run the Pester suite on hosted Windows and Ubuntu runners.
- Build, install, import, and invoke a generated module through a real Linux container in hosted and local CI.
- Inspect repositories and ordered plugin execution diagnostics without generating build output.

The basic Version 1 workflow is implemented. Remaining work focuses on testing the packaged generator itself, stabilizing release-quality gates, hardening repository inspection, completing runnable examples, and reconciling the documentation before a release candidate. The public plugin SDK and additional container runtimes remain deferred to Phase 2.

See [TODO.md](TODO.md) for the complete remaining Version 1 roadmap, release-readiness work, and Phase 2 deferrals.

## How it is intended to work

1. A repository defines its module in `PSModule/PSModule.psd1`.
2. `Build-ContainerModule` inspects the repository and builds an internal object model.
3. Validators, generators, templates, and packaging providers produce the module.
4. The generated module is copied into the container image at `/PSModule`.
5. Users install it locally with `Install-ContainerModule` and invoke its commands like any other PowerShell module.

```powershell
Install-ContainerModule ghcr.io/the-running-dev/build-agent:latest

Invoke-BuildAgent -Repository . -Task Build

Get-Help Invoke-BuildAgent
```

Docker is the initial container runtime. The mapping model is designed so that future runtime adapters, such as Podman, can consume the same repository specification.

## Current architecture

The generator uses a plugin-oriented pipeline. Specifications reject unknown mapping and validation types, and may assign globally unique stable IDs to the root, commands, and parameters:

```text
Repository
    -> Inspectors
    -> Validators
    -> Object Model Processors
    -> Runtime Adapters
    -> Code Generators
    -> Template Renderers
    -> Packaging Providers
```

Inspectors may analyze Dockerfiles, Compose files, README files, build systems, project files, configuration schemas, OpenAPI definitions, and other repository artifacts. Plugin execution is ordered by filename prefix.

The generated module may contain public cmdlets, private helpers, parameter declarations, validation, completion, help, Docker invocation, preview and diagnostic support, and error handling. It does not depend on a shared runtime library.

## Specification

See [Specifications.md](Specifications.md) for the Version 1 working draft, including the repository layout, object model, mappings, extensibility model, generated output, and success criteria.

## Requirements

- PowerShell 7.4 or later for inspection and generation.
- Docker for installing embedded modules, invoking generated container commands, and
  running the container end-to-end workflow.

Windows and Linux are the supported Version 1 platforms and are validated in CI.
macOS is best-effort for Version 1 and is not part of the required CI matrix.

## Development

The module source is stored directly under `src/`:

```text
src/
├── SubZeroDev.ContainerPSGenerator.psd1
├── SubZeroDev.ContainerPSGenerator.psm1
├── Public/
└── Private/
```

### Try the module locally

From the repository root, import the development manifest:

```powershell
Import-Module ./src/SubZeroDev.ContainerPSGenerator.psd1 -Force
Get-Command -Module SubZeroDev.ContainerPSGenerator
```

Inspect an ordered plugin layout without executing plugin code:

```powershell
Get-ContainerModulePlugin -Path ./PSModule/Plugins
Get-ContainerModulePlugin -Path ./PSModule/Plugins -Stage Inspectors, Validators
```

Plugin roots may contain `Inspectors`, `Validators`, `ObjectModelProcessors`, `CodeGenerators`, `TemplateRenderers`, `RuntimeAdapters`, and `PackagingProviders` directories. Plugin filenames must follow the `<numeric-prefix>.<name>.ps1` convention, such as `00.DockerfileInspector.ps1`. The built-in Docker runtime adapter selects Docker command rendering for container-backed commands; inferred PowerShell scripts and module functions continue to execute from their packaged local sources.

`Build-ContainerModule` automatically uses a `Plugins` directory beside the resolved specification. Pass `-PluginPath` to select one or more other plugin roots. The internal pipeline runner invokes each plugin with a shared `Context` parameter and records its stage, path, timing, success, and any error. The built-in packaging provider validates the completed module layout and publishes the output directory as the `Package` artifact for subsequent providers. The public plugin SDK remains deferred to Phase 2.

Built-in specification validation and object-model normalization use the same ordered plugin pipeline. `Build-ContainerModule` now orchestrates these stages without directly implementing either concern, while `Test-ContainerModuleSpecification` and `Get-ContainerModuleModel` run the corresponding built-in stages independently.

Inspect a repository without generating a module, then view ordered plugin diagnostics:

```powershell
$inspection = Get-ContainerModuleInspection -Specification ./PSModule/PSModule.psd1
$inspection.Data
$inspection | Get-ContainerModuleDiagnostic
$inspection | Get-ContainerModuleDiagnostic -Detailed
```

The concise diagnostic view reports stage, execution order, plugin, duration, and success for readable CI logs. Use `-Detailed` to include the resolved plugin path, start time, and error text while troubleshooting.

Repository plugins are trusted code, not sandboxed extensions. Inspect plugin scripts before running the generator and only use plugin roots from repositories and sources you trust. A plugin receives the shared build context and runs with the same filesystem, process, network, and credential access as the PowerShell process invoking this module.

Install a generated module embedded at `/PSModule` in a container image:

```powershell
Install-ContainerModule ghcr.io/example/example-container:latest
```

The default destination is `~/PSModule`. Preview the create/copy/remove operation or select another directory:

```powershell
Install-ContainerModule ghcr.io/example/example-container:latest -WhatIf
Install-ContainerModule ghcr.io/example/example-container:latest -Destination ~/Modules/ExampleContainer
```

Extraction is staged and the embedded manifest is validated before installation. Existing destinations are preserved unless replacement is explicitly requested:

```powershell
Install-ContainerModule ghcr.io/example/example-container:latest -Destination ~/Modules/ExampleContainer -Force
```

Validate the included example specification:

```powershell
Test-ContainerModuleSpecification `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1
```

A valid specification returns `True`. Invalid files produce a focused error identifying the first rule that failed. Copy the example PSD1 to experiment with command and parameter definitions.

`Build-ContainerModule` loads and validates the specification, builds the normalized model, clears the selected output directory, and writes a deterministic module package:

```powershell
Build-ContainerModule `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1 `
    -Output ./artifacts/PSModule
```

Generated artifacts currently include:

```text
artifacts/PSModule/
├── <ModuleName>.psd1
├── <ModuleName>.psm1
├── Documentation/<CommandName>.md
├── Metadata/model.json
└── Public/<CommandName>.ps1
```

Import the generated module through its manifest:

```powershell
Import-Module ./artifacts/PSModule/ExampleContainer.psd1 -Force
```

The generated manifest declares the module version and exported functions, while the loader imports every public command. Public command files render supported native validation and static argument completion attributes, and translate `Mount`, `Volume`, `Device`, `Gpu`, `ResourceLimit`, `Secret`, `Environment`, `Port`, `WorkingDirectory`, `RuntimeOption`, and `Argument` parameter mappings into a `docker run --rm` invocation using the configured `ContainerImage`. They expose synopsis, descriptions, notes, parameter help, and structured examples through `Get-Help`, generate matching Markdown command references, support `-WhatIf` previews, and report a focused error when Docker is unavailable or exits unsuccessfully.

Preview a generated invocation without requiring or starting Docker:

```powershell
Invoke-Example -Repository . -Message 'hello' -WhatIf
Get-Help Invoke-Example -Full
```

### Test another local repository

The [LLMs PowerShell module discovery specification](docs/LLMs-PowerShell-Module-Discovery-Specification.md)
is an implementation-ready migration brief for making the LLMs repository's
existing module exports and standalone component scripts discoverable without
exposing setup orchestrators or container infrastructure.

Clone or use any repository independently, then point the repository harness at its
local checkout. Test repositories are intentionally not embedded as Git submodules:

```powershell
./build/Test-LocalRepository.ps1 -Repository ../MyContainerRepository
```

When the target does not contain a specification, the harness creates
`PSModule/PSModule.psd1` from repository inspection and then returns its validated
model. The scaffold infers repository identity, a documented GHCR image reference,
standalone `*.ps1` scripts and explicitly exported functions from `.psm1` modules
beneath the repository's `scripts` directory. Files elsewhere in the repository are
not inferred as commands. Review inferred commands and add runtime
mappings before publishing. Runtime intent is repository-specific, so the generator
does not guess mappings from script names or paths. An existing specification with
no commands is refreshed from discovery. Generated, unmapped scaffolds are refreshed
on later runs so newly discovered scripts appear automatically; authored
specifications and scaffolds with runtime mappings are preserved. Initial creation or
refresh also materializes the inferred commands under `artifacts/PSModule/Public`
while returning the validated model. Use `-NoInitialize` to retain strict behavior
without creation or refresh.

To materialize inferred definitions as importable command files under
`artifacts/PSModule/Public`, run:

```powershell
./build/Test-LocalRepository.ps1 -Repository ../MyContainerRepository -Generate
```

The script imports this checkout of ContainerPSGenerator, validates the target repository's specification, and returns its normalized object model. Select non-default paths when needed:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -Specification ./config/MyModule.psd1 `
    -Output ./dist
```

To continue into the generation pipeline, add `-Generate`:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -Generate
```

The harness invokes the real `Build-ContainerModule` entry point. The command returns
the generated `Metadata/model.json`; the complete validated module package is written
to the selected output directory.

To generate the module, import it into the current PowerShell session, and show the
commands available for testing, run:

```powershell
./build/Test-LocalRepository.ps1 `
    -Repository ../MyContainerRepository `
    -ListCommands
```

The returned command objects include their names and parameter metadata. Because the
generated module is imported globally, you can invoke a listed command immediately
after the harness returns.

Preview a generated Docker invocation before running it:

```powershell
Invoke-MyCommand -WhatIf
```

Trace the exact Docker command, attachment behavior, elapsed time, and exit code:

```powershell
Invoke-MyCommand -Verbose
```

The repository's complete `scripts` tree is copied once into the generated module's
`Scripts` directory, preserving entry points, modules, sibling helpers, and supporting
files. Inferred commands with `SourceKind = 'Script'` invoke their packaged `.ps1`
file. Inferred `ModuleFunction` commands import their packaged `.psm1` from that same
tree and invoke the exported function module-qualified. Paths relative to the source
`scripts` directory are preserved, and wrappers resolve them relative to the module
instead of embedding development-machine paths.
Commands without a supported source kind remain container wrappers and require a
real `ContainerImage` plus runtime mappings.

### Run the tests

Run the fast test suite directly with Pester:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

Run the real Docker end-to-end fixture directly:

```powershell
$configuration = New-PesterConfiguration
$configuration.Run.Path = './tests-e2e'
$configuration.Run.Exit = $true
$configuration.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $configuration
```

This generates `ContainerE2E`, embeds it at `/PSModule` in a Linux image, installs and imports it from that image, invokes its generated command with argument/environment/mount mappings, verifies help and `-WhatIf`, and removes the temporary image afterward.

To exercise the GitHub Actions workflow locally, install [Docker](https://docs.docker.com/get-docker/) and [act](https://nektosact.com/installation/index.html), ensure Docker is running, and execute:

```powershell
./build/Invoke-CI.ps1
```

The script builds a local act runner image with PowerShell, then runs both the `ubuntu-latest` Pester matrix leg and the real `container-e2e` job from `.github/workflows/test.yml`. The base images are downloaded on the first run; later runs reuse Docker's build cache.

Because `act` itself runs inside a container, its nested Docker daemon cannot access test files created inside the runner's private `/tmp` directory. The local CI path therefore validates a shared `/tmp` bind mount, while direct and hosted runs additionally verify the mounted sentinel file and content.

Act uses Linux containers and cannot faithfully reproduce GitHub's hosted Windows runner. Run the direct Pester command on Windows for fast host-platform feedback; GitHub Actions remains authoritative for both the Windows and Ubuntu jobs.

Each hosted workflow run publishes the Windows and Ubuntu unit results, the container
end-to-end results, and a Linux code-coverage summary directly on the Actions run.
The underlying NUnit and JaCoCo XML reports are also available as downloadable
workflow artifacts. GitHub-only reporting steps are skipped when the workflow runs
locally through `act`.

## License

No license has been selected yet.
