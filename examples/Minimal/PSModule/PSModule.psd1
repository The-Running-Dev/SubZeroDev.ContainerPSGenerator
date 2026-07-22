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
            )
        }
    )
}
