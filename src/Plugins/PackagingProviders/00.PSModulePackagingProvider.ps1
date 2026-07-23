param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$Context.Artifacts['Package'] = Complete-ContainerModulePackage -Context $Context
