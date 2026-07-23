param ([Parameter(Mandatory)] [psobject] $Context)

$excluded = @('.git', 'node_modules', 'artifacts', 'bin', 'obj')
$outputPrefix = $Context.OutputPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$items = @(Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File | Where-Object {
    $_.Extension -in @('.ps1', '.psm1', '.psd1') -and
    -not $_.FullName.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    -not (@($_.FullName.Substring($Context.RepositoryPath.Length).Split([IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)) |
        Where-Object { $_ -in $excluded })
})
[Array]::Sort($items, [Collections.Generic.Comparer[object]]::Create({ param($a,$b) [StringComparer]::Ordinal.Compare($a.FullName,$b.FullName) }))

$files = foreach ($item in $items) {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($item.FullName, [ref]$tokens, [ref]$errors)
    [ordered]@{
        Path        = [IO.Path]::GetRelativePath($Context.RepositoryPath, $item.FullName).Replace('\','/')
        Type        = $item.Extension.TrimStart('.').ToUpperInvariant()
        Functions   = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object Name)
        Classes     = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.TypeDefinitionAst] -and $node.IsClass }, $true) | ForEach-Object Name)
        ParseErrors = @($errors | ForEach-Object Message)
    }
}
$Context.Inspection['PowerShellFiles'] = @($files)
