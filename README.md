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

The generator uses a plugin-oriented pipeline:

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
├── Metadata/model.json
└── Public/<CommandName>.ps1
```

Import the generated module through its manifest:

```powershell
Import-Module ./artifacts/PSModule/ExampleContainer.psd1 -Force
```

The generated manifest declares the module version and exported functions, while the loader imports every public command. Public command files render supported native validation attributes and translate `Mount`, `Volume`, `Environment`, `Port`, `WorkingDirectory`, `RuntimeOption`, and `Argument` parameter mappings into a `docker run --rm` invocation using the configured `ContainerImage`. They expose specification descriptions through `Get-Help`, support `-WhatIf` previews, and report a focused error when Docker is unavailable or exits unsuccessfully. Additional mapping types will be added in later slices.

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
