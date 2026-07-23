param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

Invoke-ContainerModuleSpecificationValidation `
    -Specification $Context.Specification `
    -SpecificationPath $Context.SpecificationPath
