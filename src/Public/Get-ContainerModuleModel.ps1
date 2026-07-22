function Get-ContainerModuleModel {
    <#
    .SYNOPSIS
    Builds the normalized model for a container module specification.

    .DESCRIPTION
    Loads and validates a PowerShell data-file specification, then returns the normalized
    object model consumed by later generator stages.

    .PARAMETER Specification
    Path to the repository's PowerShell data-file specification.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1'
    )

    $specificationData = Import-ContainerModuleSpecification -Path $Specification
    Assert-ContainerModuleSpecification -Specification $specificationData
    ConvertTo-ContainerModuleModel -Specification $specificationData
}
