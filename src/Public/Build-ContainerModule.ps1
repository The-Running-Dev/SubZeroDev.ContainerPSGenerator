function Build-ContainerModule {
    <#
    .SYNOPSIS
    Generates a repository-specific PowerShell module.

    .DESCRIPTION
    Builds a self-contained PowerShell module from a repository specification. Plugins
    are discovered from a sibling Plugins directory unless explicit roots are supplied.

    .PARAMETER Specification
    Path to the repository's PowerShell data file.

    .PARAMETER Output
    Directory where the generated module will be written.

    .PARAMETER PluginPath
    One or more plugin roots. When omitted, the Plugins directory beside the resolved
    specification is used when it exists.
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter()]
        [string] $Output = 'artifacts/PSModule',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $PluginPath
    )

    $context = New-ContainerModuleBuildContext -SpecificationPath $Specification -OutputPath $Output
    [string[]] $pluginRoots = @((Join-Path $PSScriptRoot '..' 'Plugins'))
    if ($PSBoundParameters.ContainsKey('PluginPath')) {
        $pluginRoots += @($PluginPath)
    }
    else {
        $conventionalPluginPath = Join-Path (Split-Path $context.SpecificationPath -Parent) 'Plugins'
        if (Test-Path -LiteralPath $conventionalPluginPath -PathType Container) {
            $pluginRoots += @($conventionalPluginPath)
        }
    }

    foreach ($stage in @(
        'Inspectors'
        'Validators'
        'ObjectModelProcessors'
        'RuntimeAdapters'
        'CodeGenerators'
        'TemplateRenderers'
        'PackagingProviders'
    )) {
        Invoke-ContainerModuleBuildStage `
            -Context $context `
            -PluginPath $pluginRoots `
            -Stage $stage
    }

    return $context.Artifacts['Metadata']
}
