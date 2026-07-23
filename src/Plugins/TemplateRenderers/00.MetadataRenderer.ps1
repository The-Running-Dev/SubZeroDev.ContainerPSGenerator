param ([Parameter(Mandatory)] [psobject] $Context)

if ($Context.RenderRequests.Contains('Metadata')) {
    $Context.Artifacts['Metadata'] = Write-ContainerModuleMetadata -Context $Context
}
