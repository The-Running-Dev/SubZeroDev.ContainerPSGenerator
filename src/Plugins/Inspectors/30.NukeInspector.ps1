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
if ($Context.Inspection.Contains('PowerShellFiles')) {
    $buildScripts = @($Context.Inspection.PowerShellFiles | Where-Object { $_.Path -match '(^|/)build\.ps1$' } | ForEach-Object Path)
}
$Context.Inspection['Nuke'] = [ordered]@{
    IsConfigured   = (Test-Path -LiteralPath $nukeDirectory -PathType Container) -or $projectPaths.Count -gt 0
    ParameterNames = $parameters
    ProjectPaths   = $projectPaths
    BuildScripts   = $buildScripts
}
