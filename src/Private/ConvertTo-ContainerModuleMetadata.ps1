function ConvertTo-ContainerModuleMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Model
    )

    [ordered] @{
        SchemaVersion = 1
        ModuleName    = $Model.ModuleName
        ModuleVersion = $Model.ModuleVersion
        Commands      = @(
            foreach ($command in $Model.Commands) {
                [ordered] @{
                    Id          = $command.Id
                    Name        = $command.Name
                    Description = $command.Description
                    Parameters  = @(
                        foreach ($parameter in $command.Parameters) {
                            [ordered] @{
                                Id        = $parameter.Id
                                Name      = $parameter.Name
                                Type      = $parameter.Type
                                Mandatory = $parameter.Mandatory
                                Mappings  = @(
                                    foreach ($mapping in $parameter.Mappings) {
                                        $metadata = [ordered] @{ Type = $mapping.Type }
                                        foreach ($key in @($mapping.Definition.Keys | Sort-Object)) {
                                            if ($key -ne 'Type') {
                                                $metadata[$key] = $mapping.Definition[$key]
                                            }
                                        }
                                        $metadata
                                    }
                                )
                            }
                        }
                    )
                }
            }
        )
    }
}
