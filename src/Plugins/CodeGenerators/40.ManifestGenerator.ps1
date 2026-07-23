param ([Parameter(Mandatory)] [psobject] $Context)

$Context.Artifacts['Manifest'] = Write-ContainerModuleManifest -Context $Context
