function ConvertTo-ContainerModuleCommandSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Command,

        [Parameter(Mandatory)]
        [string] $ContainerImage,

        [Parameter()]
        [string] $SourceKind,

        [Parameter()]
        [string] $PackagedSourcePath
    )

    if ($SourceKind -in @('Script', 'ModuleFunction')) {
        return ConvertTo-DockerContainerModuleCommandSource @PSBoundParameters
    }

    if (-not $Command.PSObject.Properties['RuntimeAdapter'] -or
        [string]::IsNullOrWhiteSpace([string] $Command.RuntimeAdapter)) {
        throw [System.InvalidOperationException]::new(
            "Command '$($Command.Name)' does not have a runtime adapter."
        )
    }

    switch ($Command.RuntimeAdapter) {
        'Docker' {
            return ConvertTo-DockerContainerModuleCommandSource @PSBoundParameters
        }
        default {
            throw [System.NotSupportedException]::new(
                "Runtime adapter '$($Command.RuntimeAdapter)' for command '$($Command.Name)' is not supported."
            )
        }
    }
}
