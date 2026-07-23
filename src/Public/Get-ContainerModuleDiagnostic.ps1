function Get-ContainerModuleDiagnostic {
    <#
    .SYNOPSIS
    Returns ordered repository inspector execution diagnostics.

    .DESCRIPTION
    Returns typed plugin execution diagnostics from an existing inspection result,
    or runs repository inspection and returns its diagnostics directly.

    .PARAMETER InputObject
    An inspection result returned by Get-ContainerModuleInspection.

    .PARAMETER Specification
    Path to the repository specification when running a new inspection.

    .PARAMETER PluginPath
    One or more additional plugin roots when running a new inspection.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Run')]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Input')]
        [ValidateNotNull()]
        [psobject] $InputObject,

        [Parameter(ParameterSetName = 'Run')]
        [string] $Specification = 'PSModule/PSModule.psd1',

        [Parameter(ParameterSetName = 'Run')]
        [ValidateNotNullOrEmpty()]
        [string[]] $PluginPath
    )

    process {
        $inspection = if ($PSCmdlet.ParameterSetName -eq 'Input') {
            if ($InputObject.PSObject.TypeNames -notcontains 'SubZeroDev.ContainerPSGenerator.InspectionResult') {
                throw [System.ArgumentException]::new(
                    'InputObject must be returned by Get-ContainerModuleInspection.'
                )
            }
            $InputObject
        }
        else {
            $parameters = @{ Specification = $Specification }
            if ($PSBoundParameters.ContainsKey('PluginPath')) { $parameters.PluginPath = $PluginPath }
            Get-ContainerModuleInspection @parameters
        }

        foreach ($execution in $inspection.PluginExecutions) {
            [pscustomobject] @{
                PSTypeName           = 'SubZeroDev.ContainerPSGenerator.Diagnostic'
                Stage                = $execution.Stage
                ExecutionOrder       = $execution.ExecutionOrder
                Plugin               = $execution.Plugin
                Path                 = $execution.Path
                StartedAt            = $execution.StartedAt
                DurationMilliseconds = [math]::Round($execution.Duration.TotalMilliseconds, 3)
                Succeeded            = $execution.Succeeded
                Error                = $execution.Error
            }
        }
    }
}
