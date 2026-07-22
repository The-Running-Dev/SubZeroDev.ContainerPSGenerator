function Build-ContainerModule {
    <#
    .SYNOPSIS
    Generates a repository-specific PowerShell module.

    .DESCRIPTION
    Builds a self-contained PowerShell module from a repository specification.
    Generation will be introduced in a subsequent implementation slice.

    .PARAMETER Specification
    Path to the repository's PowerShell data file.

    .PARAMETER Output
    Directory where the generated module will be written.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [string] $Output = 'artifacts/PSModule'
    )

    $context = New-ContainerModuleBuildContext -SpecificationPath $Specification -OutputPath $Output
    Assert-ContainerModuleSpecification -Specification $context.Specification
    $context.Model = ConvertTo-ContainerModuleModel -Specification $context.Specification
    $metadataArtifact = Write-ContainerModuleMetadata -Context $context
    Write-ContainerModuleCommandSource -Context $context
    Write-ContainerModuleLoader -Context $context

    return $metadataArtifact
}
