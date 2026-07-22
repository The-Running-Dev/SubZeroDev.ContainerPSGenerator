@{
    ModuleName = 'ExampleContainer'
    ModuleVersion = '0.1.0'
    ContainerImage = 'ghcr.io/example/example-container:latest'

    Commands = @(
        @{
            Name        = 'Invoke-Example'
            Description = 'Runs the example container command.'

            Parameters = @(
                @{
                    Name      = 'Repository'
                    Description = 'Repository directory mounted read-only at /repository.'
                    Type      = 'DirectoryInfo'
                    Mandatory = $true

                    Mappings = @(
                        @{
                            Type   = 'Mount'
                            Target = '/repository'
                            Access = 'ReadOnly'
                        }
                    )
                }
                @{
                    Name      = 'Message'
                    Description = 'Message passed to the example container.'
                    Type      = 'string'
                    Mandatory = $true

                    Validations = @(
                        @{ Type = 'ValidatePattern'; Pattern = '^.{1,100}$' }
                    )

                    Mappings = @(
                        @{
                            Type = 'Environment'
                            Name = 'EXAMPLE_MESSAGE'
                        }
                        @{
                            Type = 'Argument'
                            Name = '--message'
                        }
                    )
                }
                @{
                    Name = 'HostPort'
                    Description = 'Optional host port published to container port 8080.'
                    Type = 'int'
                    Mappings = @(
                        @{ Type = 'Port'; ContainerPort = 8080; Protocol = 'tcp' }
                    )
                }
                @{
                    Name = 'WorkingDirectory'
                    Description = 'Optional working directory inside the container.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'WorkingDirectory' }
                    )
                }
                @{
                    Name = 'CacheVolume'
                    Description = 'Optional Docker volume mounted read-write at /cache.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'Volume'; Target = '/cache'; Access = 'ReadWrite' }
                    )
                }
                @{
                    Name = 'Network'
                    Description = 'Optional Docker network name.'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'RuntimeOption'; Name = '--network' }
                    )
                }
            )
        }
    )
}
