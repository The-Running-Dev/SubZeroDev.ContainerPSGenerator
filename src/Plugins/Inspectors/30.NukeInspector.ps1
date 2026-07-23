param ([Parameter(Mandatory)] [psobject] $Context)

$nukeDirectory = Join-Path $Context.RepositoryPath '.nuke'
[string[]] $parameters = @()
$parameterFile = Join-Path $nukeDirectory 'parameters.json'
if (Test-Path -LiteralPath $parameterFile -PathType Leaf) {
    $data = Get-Content -LiteralPath $parameterFile -Raw | ConvertFrom-Json
    $parameters = @($data.PSObject.Properties.Name)
    [Array]::Sort($parameters, [StringComparer]::Ordinal)
}
[string[]] $projectPaths = @()
if ($Context.Inspection.Contains('DotNetProjects')) {
    $projectPaths = @($Context.Inspection.DotNetProjects | Where-Object {
        $_.PackageReferences.Name -contains 'Nuke.Common'
    } | ForEach-Object Path)
}
[string[]] $buildScripts = @()
$buildScriptItems = @(Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File -Filter 'build.ps1' |
    Where-Object { Test-ContainerModuleInspectionPath -Context $Context -Path $_.FullName })
if ($buildScriptItems.Count -gt 0) {
    $buildScripts = @($buildScriptItems | ForEach-Object {
        [IO.Path]::GetRelativePath($Context.RepositoryPath, $_.FullName).Replace('\', '/')
    })
    [Array]::Sort($buildScripts, [StringComparer]::Ordinal)
}
$Context.Inspection['Nuke'] = [ordered]@{
    IsConfigured   = (Test-Path -LiteralPath $nukeDirectory -PathType Container) -or $projectPaths.Count -gt 0
    ParameterNames = $parameters
    ProjectPaths   = $projectPaths
    BuildScripts   = $buildScripts
}
