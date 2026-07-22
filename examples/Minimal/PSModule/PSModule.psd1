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
