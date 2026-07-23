function Initialize-ContainerModuleSpecification {
    <#
    .SYNOPSIS
    Creates an initial container module specification from repository inspection.

    .DESCRIPTION
    Creates a missing PSModule specification using repository identity, documented
    container image references, standalone scripts in the repository root and beneath
    scripts directories, and functions explicitly exported by modules beneath modules
    directories.

    The generated specification is a scaffold. Review inferred commands and add their
    container argument, environment, mount, and runtime mappings before publishing.

    .PARAMETER Repository
    Repository to inspect.

    .PARAMETER Specification
    Specification path relative to Repository, or an absolute path.

    .PARAMETER Force
    Replaces an existing specification.

    .PARAMETER PassThru
    Returns the created specification file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()]
        [string] $Repository = '.',

        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )

    if (-not (Test-Path -LiteralPath $Repository -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new("Repository was not found: '$Repository'.")
    }
    $repositoryPath = (Resolve-Path -LiteralPath $Repository).ProviderPath
    $specificationPath = if ([IO.Path]::IsPathRooted($Specification)) {
        [IO.Path]::GetFullPath($Specification)
    }
    else {
        [IO.Path]::GetFullPath((Join-Path $repositoryPath $Specification))
    }

    if ((Test-Path -LiteralPath $specificationPath -PathType Leaf) -and -not $Force) {
        throw [System.IO.IOException]::new(
            "Container module specification already exists: '$specificationPath'. Use -Force to replace it."
        )
    }
    if (-not $PSCmdlet.ShouldProcess($specificationPath, 'Create container module specification')) { return }

    $definition = Get-ContainerModuleSpecificationCandidate -RepositoryPath $repositoryPath
    $source = ConvertTo-ContainerModuleSpecificationSource -Specification $definition
    $directory = Split-Path $specificationPath -Parent
    $null = New-Item -Path $directory -ItemType Directory -Force
    Set-Content -LiteralPath $specificationPath -Value $source -Encoding utf8NoBOM -NoNewline

    if ($PassThru) { Get-Item -LiteralPath $specificationPath }
}
