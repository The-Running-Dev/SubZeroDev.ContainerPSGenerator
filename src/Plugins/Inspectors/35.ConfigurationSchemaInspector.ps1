param ([Parameter(Mandatory)] [psobject] $Context)

$items = @(Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File -Filter '*.json' | Where-Object {
    Test-ContainerModuleInspectionPath -Context $Context -Path $_.FullName
})
[Array]::Sort($items, [Collections.Generic.Comparer[object]]::Create({ param($a,$b) [StringComparer]::Ordinal.Compare($a.FullName,$b.FullName) }))

$schemas = foreach ($item in $items) {
    $data = Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json
    if ($item.Name -notmatch '\.schema\.json$' -and -not $data.PSObject.Properties['$schema']) { continue }
    $properties = if ($data.PSObject.Properties['properties']) { @($data.properties.PSObject.Properties.Name) } else { @() }
    [Array]::Sort($properties, [StringComparer]::Ordinal)
    $required = if ($data.PSObject.Properties['required']) { @($data.required) } else { @() }
    [Array]::Sort($required, [StringComparer]::Ordinal)
    [ordered]@{
        Path = [IO.Path]::GetRelativePath($Context.RepositoryPath,$item.FullName).Replace('\','/')
        Schema = if ($data.PSObject.Properties['$schema']) { $data.'$schema' } else { $null }
        Id = if ($data.PSObject.Properties['$id']) { $data.'$id' } else { $null }
        Title = if ($data.PSObject.Properties['title']) { $data.title } else { $null }
        Type = if ($data.PSObject.Properties['type']) { $data.type } else { $null }
        Required = $required
        Properties = $properties
    }
}
$Context.Inspection['ConfigurationSchemas'] = @($schemas)
