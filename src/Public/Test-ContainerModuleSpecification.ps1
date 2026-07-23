function Test-ContainerModuleSpecification {
    <#
    .SYNOPSIS
    Validates a container module specification.

    .DESCRIPTION
    Loads a PowerShell data-file specification and runs all currently implemented validators.
    Returns true when the specification is valid. Invalid specifications produce a terminating error.

    .PARAMETER Specification
    Path to the repository's PowerShell data-file specification.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1'
    )

    $specificationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Specification)
    $context = New-ContainerModuleBuildContext `
        -SpecificationPath $specificationPath `
        -OutputPath (Join-Path (Split-Path $specificationPath -Parent) '.container-module-validation')
    $null = Invoke-ContainerModulePluginPipeline `
        -Context $context `
        -Path (Join-Path $PSScriptRoot '..' 'Plugins') `
        -Stage Validators

    return $true
}
