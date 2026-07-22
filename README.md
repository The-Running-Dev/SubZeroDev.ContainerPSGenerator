# SubZeroDev.ContainerPSGenerator

SubZeroDev.ContainerPSGenerator is a proposed PowerShell 7+ build tool for generating repository-specific PowerShell modules for containerized applications.

Repositories describe their public interface in a declarative PowerShell data file. During the normal repository build, the generator produces a complete, self-contained module that is embedded in the container image. Users can then install that module from the image and work with native PowerShell commands instead of assembling `docker run` invocations manually.

> **Status:** Version 1 specification (working draft). The implementation is not yet available.

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

## License

No license has been selected yet.
