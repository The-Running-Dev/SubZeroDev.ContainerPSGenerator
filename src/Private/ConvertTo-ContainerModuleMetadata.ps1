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
        ContainerImage = $Model.ContainerImage
        Commands      = @(
            foreach ($command in $Model.Commands) {
                [ordered] @{
                    Id          = $command.Id
                    Name        = $command.Name
                    Synopsis    = $command.Synopsis
                    Description = $command.Description
                    Notes       = $command.Notes
                    Examples    = @(
                        foreach ($example in $command.Examples) {
                            [ordered] @{
                                Code        = $example.Code
                                Description = $example.Description
                            }
                        }
                    )
                    Parameters  = @(
                        foreach ($parameter in $command.Parameters) {
                            [ordered] @{
                                Id        = $parameter.Id
                                Name      = $parameter.Name
                                Description = $parameter.Description
                                Type      = $parameter.Type
                                Mandatory = $parameter.Mandatory
                                Validations = @(
                                    foreach ($validation in $parameter.Validations) {
                                        $metadata = [ordered] @{ Type = $validation.Type }
                                        foreach ($key in @($validation.Definition.Keys | Sort-Object)) {
                                            if ($key -ne 'Type') { $metadata[$key] = $validation.Definition[$key] }
                                        }
                                        $metadata
                                    }
                                )
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
