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
        $packagedSourcePath = $null
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
            $scriptsPrefix = (Join-Path $Context.RepositoryPath 'scripts').TrimEnd(
                [IO.Path]::DirectorySeparatorChar,
                [IO.Path]::AltDirectorySeparatorChar
            ) + [IO.Path]::DirectorySeparatorChar
            if (-not $resolvedSourcePath.StartsWith($scriptsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw [System.IO.InvalidDataException]::new(
                    "SourcePath for command '$($command.Name)' must be beneath the repository's 'scripts' directory."
                )
            }
            if (-not (Test-Path -LiteralPath $resolvedSourcePath -PathType Leaf)) {
                throw [System.IO.FileNotFoundException]::new(
                    "SourcePath for command '$($command.Name)' was not found.",
                    $resolvedSourcePath
                )
            }

            $packageDirectory = if ($sourceKind -eq 'Script') { 'Scripts' } else { 'Modules' }
            $scriptsRelativePath = [IO.Path]::GetRelativePath(
                (Join-Path $Context.RepositoryPath 'scripts'),
                $resolvedSourcePath
            )
            $packagedSourcePath = Join-Path $packageDirectory $scriptsRelativePath
            $destinationPath = Join-Path $Context.OutputPath $packagedSourcePath
            $null = New-Item -Path (Split-Path $destinationPath -Parent) -ItemType Directory -Force
            Copy-Item -LiteralPath $resolvedSourcePath -Destination $destinationPath -Force
        }
        $source = ConvertTo-ContainerModuleCommandSource `
            -Command $command `
            -ContainerImage $Context.Model.ContainerImage `
            -SourceKind $sourceKind `
            -PackagedSourcePath $packagedSourcePath
        [System.IO.File]::WriteAllText(
            $sourcePath,
            $source,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
