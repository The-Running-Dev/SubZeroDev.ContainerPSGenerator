function Install-ContainerModule {
    <#
    .SYNOPSIS
    Installs a generated PowerShell module from a container image.

    .DESCRIPTION
    Creates a temporary container, copies its /PSModule contents to the selected local directory, and always removes the temporary container.

    .PARAMETER Image
    Container image containing a generated module at /PSModule.

    .PARAMETER Destination
    Local directory that receives the module files. Defaults to ~/PSModule.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._/:@-]*$')]
        [string] $Image,

        [Parameter()]
        [string] $Destination = (Join-Path ([System.Environment]::GetFolderPath('UserProfile')) 'PSModule')
    )

    $destinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    if (-not $PSCmdlet.ShouldProcess($destinationPath, "Install /PSModule from '$Image'")) {
        return
    }

    if ($null -eq (Get-Command -Name 'docker' -ErrorAction SilentlyContinue)) {
        throw [System.InvalidOperationException]::new(
            'Docker is required to install a container module but was not found on PATH.'
        )
    }

    $global:LASTEXITCODE = 0
    $containerId = (& docker create $Image | Out-String).Trim()
    if ($global:LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($containerId)) {
        throw [System.InvalidOperationException]::new(
            "Docker could not create a temporary container from '$Image'. Exit code: $global:LASTEXITCODE."
        )
    }

    try {
        $null = New-Item -Path $destinationPath -ItemType Directory -Force
        $global:LASTEXITCODE = 0
        & docker cp "${containerId}:/PSModule/." $destinationPath
        if ($global:LASTEXITCODE -ne 0) {
            throw [System.InvalidOperationException]::new(
                "Docker could not copy /PSModule from '$Image'. Exit code: $global:LASTEXITCODE."
            )
        }
    }
    finally {
        $global:LASTEXITCODE = 0
        & docker rm --force $containerId | Out-Null
        if ($global:LASTEXITCODE -ne 0) {
            Write-Warning "Docker could not remove temporary container '$containerId'."
        }
    }

    Get-Item -LiteralPath $destinationPath
}
