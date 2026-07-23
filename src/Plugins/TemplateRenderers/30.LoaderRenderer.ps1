param ([Parameter(Mandatory)] [psobject] $Context)

if ($Context.RenderRequests.Contains('Loader')) {
    Write-ContainerModuleLoader -Context $Context
}
