param ([Parameter(Mandatory)] [psobject] $Context)

$items = @(Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File | Where-Object {
    $_.Extension -in @('.ps1', '.psm1', '.psd1') -and
    (Test-ContainerModuleInspectionPath -Context $Context -Path $_.FullName)
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
