# SubZeroDev.ContainerPSGenerator

SubZeroDev.ContainerPSGenerator is a proposed PowerShell 7+ build tool for generating repository-specific PowerShell modules for containerized applications.

Repositories describe their public interface in a declarative PowerShell data file. During the normal repository build, the generator produces a complete, self-contained module that is embedded in the container image. Users can then install that module from the image and work with native PowerShell commands instead of assembling `docker run` invocations manually.

> **Status:** Version 1 specification and implementation are under active development.

## Goals

- Keep the repository as the single source of truth.
- Generate deterministic, self-contained PowerShell source code.
- Use native PowerShell types, validation, help, and completion.
- Separate build-time inspection and generation from runtime execution.
- Support extensibility through an ordered plugin pipeline.
- Provide a cross-platform experience on PowerShell 7+.

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
- Translate bound parameters into ordered `docker run --rm` arguments for command arguments, environment variables, bind mounts, named volumes, ports, working directories, devices, GPUs, resource limits, secrets, and generic runtime options.
- Preview generated Docker invocations through `-WhatIf` and report missing-runtime or non-zero-exit failures.
- Install `/PSModule` from a container image through a staged, manifest-validated, replace-safe workflow with `-Force` and `-WhatIf` support.
- Test another local repository through `build/Test-LocalRepository.ps1` and reproduce the Linux CI job locally with `build/Invoke-CI.ps1` and `act`.
- Run the Pester suite on hosted Windows and Ubuntu runners.

Still planned for Version 1 are additional repository inspectors, richer user-facing diagnostics, and a real container end-to-end packaging test. The public plugin SDK and additional container runtimes remain deferred to Phase 2.

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

## Planned architecture

The generator uses a plugin-oriented pipeline. Specifications reject unknown mapping and validation types, and may assign globally unique stable IDs to the root, commands, and parameters:

```text
Repository
    -> Inspectors
    -> Object Model
    -> Validators
    -> Code Generators
    -> Template Renderers
    -> Packaging
```

Inspectors may analyze Dockerfiles, Compose files, README files, build systems, project files, configuration schemas, OpenAPI definitions, and other repository artifacts. Plugin execution is ordered by filename prefix.

The generated module may contain public cmdlets, private helpers, parameter declarations, validation, completion, help, Docker invocation, preview and diagnostic support, and error handling. It does not depend on a shared runtime library.

## Specification

See [Specifications.md](Specifications.md) for the Version 1 working draft, including the repository layout, object model, mappings, extensibility model, generated output, and success criteria.

## Requirements

- PowerShell 7 or later
- Docker

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

Plugin roots may contain `Inspectors`, `Validators`, `ObjectModelProcessors`, `CodeGenerators`, `TemplateRenderers`, `RuntimeAdapters`, and `PackagingProviders` directories. Plugin filenames must follow the `<numeric-prefix>.<name>.ps1` convention, such as `00.DockerfileInspector.ps1`.

`Build-ContainerModule` automatically uses a `Plugins` directory beside the resolved specification. Pass `-PluginPath` to select one or more other plugin roots. The internal pipeline runner invokes each plugin with a shared `Context` parameter and records its stage, path, timing, success, and any error. The public plugin SDK remains deferred to Phase 2.

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

Point the repository harness at any checkout containing `PSModule/PSModule.psd1`:

```powershell
./build/Test-LocalRepository.ps1 -Repository ../MyContainerRepository
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

The harness invokes the real `Build-ContainerModule` entry point. It currently returns the generated `Metadata/model.json`; additional module artifacts will appear through the same command as generation stages are added.

### Run the tests

Run the fast test suite directly with Pester:

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

To exercise the GitHub Actions workflow locally, install [Docker](https://docs.docker.com/get-docker/) and [act](https://nektosact.com/installation/index.html), ensure Docker is running, and execute:

```powershell
./build/Invoke-CI.ps1
```

The script builds a local act runner image with PowerShell, then runs the `ubuntu-latest` matrix leg from `.github/workflows/test.yml`. The base images are downloaded on the first run; later runs reuse Docker's build cache.

Act uses Linux containers and cannot faithfully reproduce GitHub's hosted Windows runner. Run the direct Pester command on Windows for fast host-platform feedback; GitHub Actions remains authoritative for both the Windows and Ubuntu jobs.

## License

No license has been selected yet.
