function Assert-ContainerModuleSpecification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    Assert-ContainerModuleCommands -Specification $Specification
    Assert-ContainerModuleParameters -Specification $Specification
}
