function ConvertTo-ContainerModuleModel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    $commands = @(
        if ($Specification.Contains('Commands')) {
            foreach ($command in $Specification['Commands']) {
                $parameters = @(
                    if ($command.Contains('Parameters')) {
                        foreach ($parameter in $command['Parameters']) {
                            $validations = @(
                                if ($parameter.Contains('Validations')) {
                                    foreach ($validation in $parameter['Validations']) {
                                        [pscustomobject] @{
                                            PSTypeName = 'SubZeroDev.ContainerPSGenerator.Model.Validation'
                                            Type       = $validation['Type']
                                            Definition = $validation
                                        }
                                    }
                                }
                            )
                            $mappings = @(
                                if ($parameter.Contains('Mappings')) {
                                    foreach ($mapping in $parameter['Mappings']) {
                                        [pscustomobject] @{
                                            PSTypeName = 'SubZeroDev.ContainerPSGenerator.Model.Mapping'
                                            Type       = $mapping['Type']
                                            Definition = $mapping
                                        }
                                    }
                                }
                            )

                            [pscustomobject] @{
                                PSTypeName = 'SubZeroDev.ContainerPSGenerator.Model.Parameter'
                                Id         = $parameter['Id']
                                Name       = $parameter['Name']
                                Description = $parameter['Description']
                                Type       = $parameter['Type']
                                Mandatory  = if ($parameter.Contains('Mandatory')) { $parameter['Mandatory'] } else { $false }
                                Validations = $validations
                                Mappings   = $mappings
                                Definition = $parameter
                            }
                        }
                    }
                )

                [pscustomobject] @{
                    PSTypeName  = 'SubZeroDev.ContainerPSGenerator.Model.Command'
                    Id          = $command['Id']
                    Name        = $command['Name']
                    Description = $command['Description']
                    Parameters  = $parameters
                    Definition  = $command
                }
            }
        }
    )

    [pscustomobject] @{
        PSTypeName    = 'SubZeroDev.ContainerPSGenerator.Model'
        ModuleName    = if ($Specification.Contains('ModuleName')) { $Specification['ModuleName'] } else { 'PSModule' }
        ModuleVersion = if ($Specification.Contains('ModuleVersion')) { $Specification['ModuleVersion'] } else { '0.1.0' }
        ContainerImage = if ($Specification.Contains('ContainerImage')) { $Specification['ContainerImage'] } else { if ($Specification.Contains('ModuleName')) { $Specification['ModuleName'] } else { 'PSModule' } }
        Commands      = $commands
        Definition    = $Specification
    }
}
