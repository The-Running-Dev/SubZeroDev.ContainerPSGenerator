<#
.SYNOPSIS
Tests ContainerPSGenerator against another local repository.

.DESCRIPTION
Imports the generator from this checkout, changes to the selected repository, and builds
its validated object model. Use Generate to continue through Build-ContainerModule.

.PARAMETER Repository
Path to the local repository to test.

.PARAMETER Specification
Specification path relative to Repository, or an absolute path.

.PARAMETER Output
Generation output path relative to Repository, or an absolute path.

.PARAMETER Generate
Runs Build-ContainerModule after model validation and returns the generated artifacts.

.PARAMETER NoInitialize
Fails when Specification is missing instead of creating an inferred scaffold.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter()]
    [string] $Specification = 'PSModule/PSModule.psd1',

    [Parameter()]
    [string] $Output = 'artifacts/PSModule',

    [Parameter()]
    [switch] $Generate,

    [Parameter()]
    [switch] $NoInitialize
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Repository -PathType Container)) {
    throw [System.IO.DirectoryNotFoundException]::new(
        "Local repository was not found: '$Repository'."
    )
}

$repositoryPath = (Resolve-Path -LiteralPath $Repository).ProviderPath
$manifestPath = Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.ContainerPSGenerator.psd1'
Import-Module $manifestPath -Force -ErrorAction Stop

Push-Location $repositoryPath
try {
    if (-not (Test-Path -LiteralPath $Specification -PathType Leaf)) {
        if ($NoInitialize) {
            throw [System.IO.FileNotFoundException]::new(
                "Container module specification was not found: '$(Join-Path $repositoryPath $Specification)'."
            )
        }
        Initialize-ContainerModuleSpecification `
            -Repository $repositoryPath `
            -Specification $Specification |
            Out-Null
        Write-Host "Created inferred container module specification: $Specification" -ForegroundColor Green
    }

    if ($Generate) {
        Build-ContainerModule -Specification $Specification -Output $Output
        return
    }

    Get-ContainerModuleModel -Specification $Specification
}
finally {
    Pop-Location
}
