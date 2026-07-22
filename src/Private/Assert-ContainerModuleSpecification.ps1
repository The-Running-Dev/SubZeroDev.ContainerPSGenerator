function Assert-ContainerModuleSpecification {
    [CmdletBinding()]
param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    Assert-ContainerModuleIdentity -Specification $Specification
    Assert-ContainerModuleRuntime -Specification $Specification
    Assert-ContainerModuleCommands -Specification $Specification
    Assert-ContainerModuleParameters -Specification $Specification
    Assert-ContainerModuleParameterValidations -Specification $Specification
    Assert-ContainerModuleMappings -Specification $Specification
    Assert-ContainerModuleNamedMappings -Specification $Specification
    Assert-ContainerModuleMountMappings -Specification $Specification
}
