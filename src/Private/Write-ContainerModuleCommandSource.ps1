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
        $sourceKind = if ($command.Definition.ContainsKey('SourceKind')) {
            [string] $command.Definition['SourceKind']
        }
        else { $null }
        $resolvedSourcePath = $null
        if ($sourceKind -in @('Script', 'ModuleFunction')) {
            $declaredSourcePath = [string] $command.Definition['SourcePath']
            if ([IO.Path]::IsPathRooted($declaredSourcePath)) {
                throw [System.IO.InvalidDataException]::new(
                    "SourcePath for command '$($command.Name)' must be relative to the repository."
                )
            }
            $resolvedSourcePath = [IO.Path]::GetFullPath((Join-Path $Context.RepositoryPath $declaredSourcePath))
            $repositoryPrefix = $Context.RepositoryPath.TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            ) + [IO.Path]::DirectorySeparatorChar
            if (-not $resolvedSourcePath.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw [System.IO.InvalidDataException]::new(
                    "SourcePath for command '$($command.Name)' resolves outside the repository."
                )
            }
        }
        $source = ConvertTo-ContainerModuleCommandSource `
            -Command $command `
            -ContainerImage $Context.Model.ContainerImage `
            -SourceKind $sourceKind `
            -ResolvedSourcePath $resolvedSourcePath
        [System.IO.File]::WriteAllText(
            $sourcePath,
            $source,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
