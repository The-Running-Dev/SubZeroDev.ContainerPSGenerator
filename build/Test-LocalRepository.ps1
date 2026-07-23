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
Fails when Specification is missing and prevents refreshing an empty scaffold.
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
    $specificationInitialized = $false
    $specificationExists = Test-Path -LiteralPath $Specification -PathType Leaf
    $refreshEmptySpecification = $false
    if ($specificationExists -and -not $NoInitialize) {
        $existingDefinition = Import-PowerShellDataFile -LiteralPath $Specification -ErrorAction Stop
        $refreshEmptySpecification = (
            -not $existingDefinition.ContainsKey('Commands') -or
            @($existingDefinition.Commands).Count -eq 0
        )
    }

    if (-not $specificationExists -or $refreshEmptySpecification) {
        if ($NoInitialize) {
            throw [System.IO.FileNotFoundException]::new(
                "Container module specification was not found: '$(Join-Path $repositoryPath $Specification)'."
            )
        }
        Initialize-ContainerModuleSpecification `
            -Repository $repositoryPath `
            -Specification $Specification `
            -Force:$refreshEmptySpecification |
            Out-Null
        $action = if ($refreshEmptySpecification) { 'Refreshed' } else { 'Created' }
        Write-Host "$action inferred container module specification: $Specification" -ForegroundColor Green
        $specificationInitialized = $true
    }

    if ($Generate -or $specificationInitialized) {
        $artifact = Build-ContainerModule -Specification $Specification -Output $Output
        if ($specificationInitialized -and -not $Generate) {
            Write-Host "Generated inferred container module: $Output" -ForegroundColor Green
        }
        if ($Generate) { $artifact }
    }
    if ($Generate) {
        return
    }

    Get-ContainerModuleModel -Specification $Specification
}
finally {
    Pop-Location
}
