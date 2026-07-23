# Roadmap and remaining work

This file tracks work that remains after the built-in repository inspector chain. The Version 1 specification remains authoritative; completed capabilities are summarized in `README.md`.

## Version 1 priorities

### 1. Developer diagnostics

- [x] Add a dedicated command that runs repository inspection without generating a module.
- [x] Add a command that returns plugin discovery and execution diagnostics, including stage, order, duration, success, and failure details.
- [x] Surface inspection results as typed PowerShell objects so developers do not need to read `Metadata/model.json`.
- [x] Include specification object IDs and source context in validation errors where available.
- [x] Add concise and detailed diagnostic views suitable for interactive use and CI logs.
- [x] Document plugin execution as trusted repository code and explain the security boundary.

### 2. Complete the internal plugin architecture

- [ ] Move built-in specification validation behind ordered validator plugins.
- [ ] Move object-model normalization and enrichment behind object-model processor plugins.
- [ ] Move command source, loader, manifest, metadata, and documentation generation behind code-generator plugins.
- [ ] Move rendering concerns behind template-renderer plugins.
- [ ] Move Docker-specific command construction behind the built-in Docker runtime-adapter plugin.
- [ ] Add a built-in packaging provider for the generated `/PSModule` layout.
- [ ] Keep `Build-ContainerModule` as the single public build command while making its stages orchestration-only.
- [ ] Preserve deterministic output and current behavior throughout the refactor.

### 3. Inspector hardening

- [ ] Add focused malformed-input behavior for Dockerfiles, Compose files, project manifests, README files, workflows, NUKE configuration, schemas, and OpenAPI documents.
- [ ] Decide whether malformed optional repository artifacts should produce warnings or fail the build, then apply the rule consistently.
- [ ] Replace the limited Compose, GitHub Actions, and OpenAPI YAML readers with a shared YAML parser or explicitly document their supported subset.
- [ ] Handle Dockerfile continuations, build arguments used by `FROM`, and additional instruction metadata.
- [ ] Add fixtures for multi-project repositories, alternate casing, spaces in paths, and symbolic links.
- [ ] Confirm recursive inspectors never traverse generated output, dependency, cache, or source-control directories.

### 4. Real container end-to-end coverage

- [x] Add a representative fixture repository and container image.
- [x] Generate its PowerShell module during the test build.
- [x] Embed the generated module at `/PSModule` in the image.
- [x] Build the image with Docker.
- [x] Install the module from the image with `Install-ContainerModule`.
- [x] Import the installed module and invoke a generated command against the container runtime.
- [ ] Verify argument, environment, mount, port, working-directory, volume, device, GPU, resource-limit, secret, and runtime-option behavior where the runner supports it.
- [x] Verify `Get-Help` and `-WhatIf` behavior in the packaged module.
- [ ] Verify generated Markdown documentation in the packaged module end-to-end.
- [x] Run the supported end-to-end path in hosted CI and through `build/Invoke-CI.ps1`/`act` locally.
- [x] Ensure temporary containers, images, staged files, and installation directories are cleaned up after success and failure.

### 5. Examples and documentation

- [ ] Expand `examples/Minimal` into a buildable, runnable container example.
- [ ] Add an example that exercises custom repository plugins.
- [ ] Add examples for every supported parameter mapping, validation, completion, and help feature.
- [ ] Document the shared plugin context and the current internal contract without promising Phase 2 API stability.
- [ ] Document every inspection metadata shape and its supported input subset.
- [ ] Add troubleshooting guidance for Docker, PowerShell, `act`, plugin failures, malformed repository artifacts, and installation failures.
- [ ] Reconcile `Specifications.md`, `README.md`, command help, and generated documentation before the Version 1 release.

### 6. Release readiness

- [ ] Add static analysis and formatting checks for PowerShell source.
- [ ] Add test coverage reporting and define a minimum acceptable threshold.
- [ ] Test the packaged generator module rather than only importing it from `src/`.
- [ ] Validate supported PowerShell 7 versions on Windows and Linux.
- [ ] Decide and document the support policy for macOS.
- [ ] Add changelog, license, contribution, and security-reporting documents as appropriate.
- [ ] Finalize module identity, versioning, tags, release notes, and distribution approach.
- [ ] Produce a release candidate and run the complete success-criteria workflow from a clean machine or runner.

## Suggested implementation sequence

1. Developer inspection and diagnostics commands.
2. Built-in validator and object-model processor plugins.
3. Built-in generator and template-renderer plugins.
4. Docker runtime adapter and `/PSModule` packaging provider.
5. Inspector hardening and shared YAML handling decision.
6. Container end-to-end fixture and CI job.
7. Examples, documentation reconciliation, and release readiness.

## Version 1 definition of done

- [ ] A repository author can define `PSModule/PSModule.psd1` and generate deterministic module output.
- [ ] The generated module is embedded at `/PSModule` in a real image.
- [ ] A user can install it with `Install-ContainerModule`, import it, invoke generated commands, and use `Get-Help` without manually constructing `docker run` arguments.
- [ ] Built-in stages run through the internal plugin pipeline and failures provide actionable diagnostics.
- [ ] Direct Pester, hosted Windows and Linux CI, local `act`, and the real container end-to-end workflow all pass.
- [ ] Documentation accurately distinguishes implemented Version 1 behavior from Phase 2 plans.

## Deferred to Phase 2

- [ ] Public and stable plugin SDK.
- [ ] Third-party plugin packaging and distribution.
- [ ] Plugin contract versioning and compatibility policy.
- [ ] Extension-model refinement.
- [ ] Object inheritance, templates, composition, and reuse mechanisms.
- [ ] Additional container runtimes such as Podman.
- [ ] Advanced documentation generation, including cross-command tutorials.
