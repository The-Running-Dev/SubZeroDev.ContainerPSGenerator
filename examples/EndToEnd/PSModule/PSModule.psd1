@{
    Id             = 'example.container-e2e'
    ModuleName     = 'ContainerE2E'
    ModuleVersion  = '0.1.0'
    ContainerImage = 'subzerodev-containerpsgenerator-e2e:local'

    Commands = @(
        @{
            Id          = 'command.invoke-container-e2e'
            Name        = 'Invoke-ContainerE2E'
            Synopsis    = 'Runs the end-to-end fixture container.'
            Description = 'Runs the fixture and returns the values observed inside its container.'
            Parameters  = @(
                @{
                    Name        = 'Message'
                    Description = 'Message passed as a container argument.'
                    Type        = 'string'
                    Mandatory   = $true
                    Mappings    = @(
                        @{ Type = 'Argument'; Name = '--message' }
                    )
                }
                @{
                    Name        = 'EnvironmentValue'
                    Description = 'Value passed through the container environment.'
                    Type        = 'string'
                    Mandatory   = $true
                    Mappings    = @(
                        @{ Type = 'Environment'; Name = 'E2E_VALUE' }
                    )
                }
                @{
                    Name        = 'Repository'
                    Description = 'Directory mounted read-only at /workspace.'
                    Type        = 'DirectoryInfo'
                    Mandatory   = $true
                    Mappings    = @(
                        @{ Type = 'Mount'; Target = '/workspace'; Access = 'ReadOnly' }
                    )
                }
            )
        }
    )
}
