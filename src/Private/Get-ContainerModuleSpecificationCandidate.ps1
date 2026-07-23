function Get-ContainerModuleSpecificationCandidate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $RepositoryPath
    )

    $repositoryName = Split-Path $RepositoryPath -Leaf
    $moduleName = [regex]::Replace($repositoryName, '[^A-Za-z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($moduleName) -or $moduleName[0] -notmatch '[A-Za-z]') {
        $moduleName = "Repository$moduleName"
    }

    $containerImage = $moduleName
    $readmePath = Join-Path $RepositoryPath 'README.md'
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $readme = Get-Content -LiteralPath $readmePath -Raw
        $imageMatch = [regex]::Match(
            $readme,
            '(?im)(?:docker\s+run(?:\s+--?\S+(?:\s+\S+)?)*\s+)?(?<Image>ghcr\.io/[a-z0-9._/-]+(?::[a-z0-9._-]+)?)'
        )
        if ($imageMatch.Success) { $containerImage = $imageMatch.Groups['Image'].Value }
    }

    $excludedDirectories = @('.git', 'node_modules', 'artifacts', 'bin', 'obj')
    $powerShellFiles = @(Get-ChildItem -LiteralPath $RepositoryPath -Recurse -File |
        Where-Object {
            $_.Extension -in @('.ps1', '.psm1') -and
            -not (@($_.FullName.Substring($RepositoryPath.Length).Split(
                [IO.Path]::DirectorySeparatorChar,
                [StringSplitOptions]::RemoveEmptyEntries
            )) | Where-Object { $_ -in $excludedDirectories })
        })

    function TestNestedRepository {
        param ([string] $Path)
        $directory = Split-Path $Path -Parent
        while ($directory -and -not [string]::Equals($directory, $RepositoryPath, [StringComparison]::OrdinalIgnoreCase)) {
            if (Test-Path -LiteralPath (Join-Path $directory '.git')) { return $true }
            $parent = Split-Path $directory -Parent
            if ($parent -eq $directory) { break }
            $directory = $parent
        }
        return $false
    }

    function GetParameterDefinitions {
        param ([Management.Automation.Language.ParamBlockAst] $ParamBlock)
        @(
            if ($ParamBlock) {
                foreach ($parameter in $ParamBlock.Parameters) {
                    $type = if ($parameter.StaticType -and $parameter.StaticType -ne [object]) {
                        $parameter.StaticType.Name
                    }
                    else { 'string' }
                    [ordered]@{
                        Name        = $parameter.Name.VariablePath.UserPath
                        Type        = $type
                        Mandatory   = [bool]($parameter.Attributes |
                            Where-Object { $_.TypeName.Name -eq 'Parameter' -and $_.Extent.Text -match '(?i)Mandatory' })
                        Description = "Discovered from $($parameter.Name.VariablePath.UserPath)."
                    }
                }
            }
        )
    }

    $commands = [System.Collections.Generic.List[object]]::new()
    $commandNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $powerShellFiles | Sort-Object FullName) {
        if (TestNestedRepository -Path $file.FullName) { continue }

        $relativePath = [IO.Path]::GetRelativePath($RepositoryPath, $file.FullName).Replace('\', '/')
        $segments = $relativePath.Split('/')
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref] $tokens,
            [ref] $parseErrors
        )
        if (@($parseErrors).Count -gt 0) { continue }

        $isRootScript = $segments.Count -eq 1
        $isScriptDirectoryScript = $segments -contains 'scripts'
        if ($file.Extension -eq '.ps1' -and ($isRootScript -or $isScriptDirectoryScript)) {
            $words = [regex]::Matches($file.BaseName, '[A-Za-z0-9]+') | ForEach-Object {
                [char]::ToUpperInvariant($_.Value[0]) + $_.Value.Substring(1)
            }
            $name = "Invoke-$($words -join '')"
            if ($commandNames.Add($name)) {
                $commands.Add([ordered]@{
                    Id          = "script.$($relativePath.ToLowerInvariant().Replace('/', '.').Replace('.ps1', ''))"
                    Name        = $name
                    Synopsis    = "Runs the discovered PowerShell script '$relativePath'."
                    Description = "Scaffolded from '$relativePath'. Review its container invocation mappings before publishing."
                    SourcePath  = $relativePath
                    SourceKind  = 'Script'
                    Parameters  = @(GetParameterDefinitions -ParamBlock $ast.ParamBlock)
                })
            }
            continue
        }

        if ($file.Extension -ne '.psm1' -or $segments -notcontains 'modules') { continue }
        $definedFunctionNames = @(
            $ast.FindAll({
                param ($node)
                $node -is [Management.Automation.Language.FunctionDefinitionAst]
            }, $true) | ForEach-Object Name
        )
        $exportedNames = @(
            $ast.FindAll({
                param ($node)
                $node -is [Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq 'Export-ModuleMember'
            }, $true) | ForEach-Object {
                $_.FindAll({
                    param ($node)
                    $node -is [Management.Automation.Language.StringConstantExpressionAst] -and
                    $node.Value -match '^[A-Za-z][A-Za-z0-9]*-[A-Za-z][A-Za-z0-9]*$'
                }, $true) | ForEach-Object Value
            } | Where-Object { $_ -in $definedFunctionNames } | Select-Object -Unique
        )
        foreach ($name in $exportedNames) {
            if (-not $commandNames.Add($name)) { continue }
            $functionAst = @($ast.FindAll({
                param ($node)
                $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $true)) | Select-Object -First 1
            $paramBlock = if ($functionAst) { $functionAst.Body.ParamBlock } else { $null }
            $commands.Add([ordered]@{
                Id          = "module.$($file.BaseName.ToLowerInvariant()).$($name.ToLowerInvariant())"
                Name        = $name
                Synopsis    = "Runs the discovered module command '$name'."
                Description = "Scaffolded from '$relativePath'. Review its container invocation mappings before publishing."
                SourcePath  = $relativePath
                SourceKind  = 'ModuleFunction'
                Parameters  = @(GetParameterDefinitions -ParamBlock $paramBlock)
            })
        }
    }

    [ordered]@{
        Id             = "repository.$($moduleName.ToLowerInvariant())"
        ModuleName     = $moduleName
        ModuleVersion  = '0.1.0'
        ContainerImage = $containerImage
        Commands       = @($commands)
    }
}
