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

    if ($pluginRoots.Count -gt 0) {
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage Inspectors
    }

    if ($pluginRoots.Count -gt 0) {
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage Validators
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage ObjectModelProcessors
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage RuntimeAdapters
    }

    if ($null -eq $context.Model) {
        throw [System.InvalidOperationException]::new(
            'The object-model processor stage did not produce a container module model.'
        )
    }

    Reset-ContainerModuleOutput -Context $context

    if ($pluginRoots.Count -gt 0) {
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage CodeGenerators
    }

    if (-not $context.Artifacts.Contains('Metadata')) {
        throw [System.InvalidOperationException]::new(
            'The code-generator stage did not produce the metadata artifact.'
        )
    }

    if ($pluginRoots.Count -gt 0) {
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage TemplateRenderers
        $null = Invoke-ContainerModulePluginPipeline -Context $context -Path $pluginRoots -Stage PackagingProviders
    }

    return $context.Artifacts['Metadata']
}
