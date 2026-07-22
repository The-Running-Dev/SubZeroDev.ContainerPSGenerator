function New-ContainerModuleBuildContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $SpecificationPath,

        [Parameter(Mandatory)]
        [string] $OutputPath
    )

    $resolvedSpecificationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $SpecificationPath
    )
    $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $OutputPath
    )
    $specification = Import-ContainerModuleSpecification -Path $resolvedSpecificationPath

    [pscustomobject] @{
        PSTypeName        = 'SubZeroDev.ContainerPSGenerator.BuildContext'
        SpecificationPath = $resolvedSpecificationPath
        OutputPath        = $resolvedOutputPath
        Specification     = $specification
        Model             = $null
    }
}
