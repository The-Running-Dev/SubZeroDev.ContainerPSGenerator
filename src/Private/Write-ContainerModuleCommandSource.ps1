function Write-ContainerModuleCommandSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Context
    )

    if ($Context.Model.Commands.Count -eq 0) {
        return
    }

    $publicDirectory = Join-Path $Context.OutputPath 'Public'
    $null = New-Item -Path $publicDirectory -ItemType Directory -Force

    foreach ($command in $Context.Model.Commands) {
        $sourcePath = Join-Path $publicDirectory "$($command.Name).ps1"
        $source = ConvertTo-ContainerModuleCommandSource -Command $command
        [System.IO.File]::WriteAllText(
            $sourcePath,
            $source,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
