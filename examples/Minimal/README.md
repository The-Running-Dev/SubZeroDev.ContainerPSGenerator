# Minimal runnable example

This example exercises the complete local lifecycle: generate a module, build an
image containing it at `/PSModule`, install and import it, invoke its generated
command, read its help, and clean up.

Docker must be running and PowerShell 7 must be available. From the repository root,
run:

```powershell
./examples/Minimal/Run-Example.ps1
```

The script returns a structured result from `Invoke-Example`, removes the imported
module and local image, and deletes its generated files. Pass `-KeepArtifacts` to
retain `examples/Minimal/artifacts` for inspection.

## Run each step manually

```powershell
Import-Module ./src/SubZeroDev.ContainerPSGenerator.psd1 -Force

Build-ContainerModule `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1 `
    -Output ./examples/Minimal/artifacts/PSModule

docker build `
    --tag subzerodev-containerpsgenerator-minimal:local `
    ./examples/Minimal

Install-ContainerModule `
    subzerodev-containerpsgenerator-minimal:local `
    -Destination ./examples/Minimal/artifacts/Installed/ExampleContainer

Import-Module `
    ./examples/Minimal/artifacts/Installed/ExampleContainer/ExampleContainer.psd1 `
    -Force

Invoke-Example `
    -Repository ./examples/Minimal `
    -Message 'hello-from-minimal'

Get-Help Invoke-Example -Full
```

Clean up the imported module, image, and generated files:

```powershell
Remove-Module ExampleContainer -Force
docker image rm --force subzerodev-containerpsgenerator-minimal:local
Remove-Item ./examples/Minimal/artifacts -Recurse -Force
```
