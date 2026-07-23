param ([Parameter(Mandatory)] [psobject] $Context)

$Context.Artifacts['Metadata'] = Write-ContainerModuleMetadata -Context $Context
