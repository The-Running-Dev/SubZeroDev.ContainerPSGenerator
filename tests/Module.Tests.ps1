BeforeAll {
    $manifestPath = Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.ContainerPSGenerator.psd1'
    Import-Module $manifestPath -Force
}

Describe 'SubZeroDev.ContainerPSGenerator module' {
    It 'has a valid module manifest' {
        Test-ModuleManifest $manifestPath -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'exports the public commands' {
        $exportedCommands = Get-Command -Module SubZeroDev.ContainerPSGenerator

        $exportedCommands.Name | Should -Contain 'Build-ContainerModule'
        $exportedCommands.Name | Should -Contain 'Get-ContainerModuleModel'
        $exportedCommands.Name | Should -Contain 'Install-ContainerModule'
        $exportedCommands.Name | Should -Contain 'Test-ContainerModuleSpecification'
    }

    It 'declares the specification and output parameters' {
        $command = Get-Command Build-ContainerModule -Module SubZeroDev.ContainerPSGenerator

        $command.Parameters.Specification.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
        $command.Parameters.Output.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
    }
}

Describe 'Test-ContainerModuleSpecification' {
    It 'returns true for a valid specification' {
        $specificationPath = Join-Path $TestDrive 'Valid.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{ Name = 'Message'; Type = 'string'; Mandatory = $true }
            )
        }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'throws the validator error for an invalid specification' {
        $specificationPath = Join-Path $TestDrive 'Invalid.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Message' }) }) }
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*non-empty string 'Type'*"
    }
}

Describe 'Build-ContainerModule specification loading' {
    BeforeEach {
        New-Item -Path (Join-Path $TestDrive 'PSModule') -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $TestDrive 'PSModule' 'PSModule.psd1') -Value '@{ Commands = @() }'
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'loads the conventional specification path by default' {
        $artifact = Build-ContainerModule

        $artifact.FullName | Should -Be (Join-Path $TestDrive 'artifacts' 'PSModule' 'Metadata' 'model.json')
    }

    It 'loads an explicitly selected specification' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Custom.psd1') -Value '@{ Commands = @() }'

        $artifact = Build-ContainerModule -Specification './Custom.psd1' -Output './dist'

        $artifact.FullName | Should -Be (Join-Path $TestDrive 'dist' 'Metadata' 'model.json')
    }

    It 'rejects a missing specification' {
        { Build-ContainerModule -Specification './missing.psd1' } |
            Should -Throw -ExceptionType ([System.IO.FileNotFoundException]) -ExpectedMessage '*Container module specification was not found*'
    }

    It 'rejects a specification that is not a PSD1 file' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Specification.ps1') -Value '@{ Commands = @() }'

        { Build-ContainerModule -Specification './Specification.ps1' } |
            Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage "*must be a PowerShell data file with a '.psd1' extension*"
    }

    It 'rejects malformed PSD1 content' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Invalid.psd1') -Value '@{ Commands = '

        { Build-ContainerModule -Specification './Invalid.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*is not a valid PowerShell data file*'
    }
}

Describe 'Container module build context' {
    BeforeAll {
        $specificationPath = Join-Path $TestDrive 'Specification.psd1'
        Set-Content -LiteralPath $specificationPath -Value '@{ Commands = @(@{ Name = ''Invoke-Example'' }) }'
    }

    It 'normalizes build paths and carries the imported specification' {
        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{
            SpecificationPath = $specificationPath
            OutputPath = Join-Path $TestDrive 'generated' '..' 'output'
        } {
            param ($SpecificationPath, $OutputPath)

            $context = New-ContainerModuleBuildContext `
                -SpecificationPath $SpecificationPath `
                -OutputPath $OutputPath

            $context.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.BuildContext'
            $context.SpecificationPath | Should -Be ([System.IO.Path]::GetFullPath($SpecificationPath))
            $context.OutputPath | Should -Be ([System.IO.Path]::GetFullPath($OutputPath))
            $context.Specification.Commands[0].Name | Should -Be 'Invoke-Example'
        }
    }

    It 'does not create the output directory while constructing the context' {
        $outputPath = Join-Path $TestDrive 'not-created'

        InModuleScope SubZeroDev.ContainerPSGenerator -Parameters @{
            SpecificationPath = $specificationPath
            OutputPath = $outputPath
        } {
            param ($SpecificationPath, $OutputPath)

            $null = New-ContainerModuleBuildContext `
                -SpecificationPath $SpecificationPath `
                -OutputPath $OutputPath

            Test-Path -LiteralPath $OutputPath | Should -BeFalse
        }
    }
}

Describe 'Build-ContainerModule command validation' {
    BeforeEach {
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'allows a specification with no commands' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{}'

        { Build-ContainerModule -Specification './Specification.psd1' } | Should -Not -Throw
    }

    It 'requires Commands to be an array' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @{ Name = ''Invoke-Example'' } }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Commands' property must be an array*"
    }

    It 'requires each command to be an object' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(''Invoke-Example'') }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*Command at index 0 must be an object*'
    }

    It 'requires each command to have a non-empty string name' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(@{ Name = '' '' }) }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Name'*"
    }

    It 'rejects case-insensitive duplicate command names' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example' }
        @{ Name = 'invoke-example' }
    )
}

Describe 'Container module identity validation' {
    It 'rejects an unsafe module name' {
        $specificationPath = Join-Path $TestDrive 'UnsafeModuleName.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ ModuleName = '../Unsafe'; Commands = @() }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'ModuleName' property must be*"
    }

    It 'rejects an invalid module version' {
        $specificationPath = Join-Path $TestDrive 'InvalidModuleVersion.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ ModuleVersion = 'latest'; Commands = @() }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'ModuleVersion' property must be a valid version string*"
    }
}
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*defined more than once*'
    }

    It 'requires PowerShell Verb-Noun command syntax' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(@{ Name = ''../../Example'' }) }'

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*must use PowerShell Verb-Noun syntax*'
    }
}

Describe 'Build-ContainerModule parameter validation' {
    BeforeEach {
        Push-Location $TestDrive
    }

    AfterEach {
        Pop-Location
    }

    It 'allows a command with no parameters' {
        Set-Content -LiteralPath './Specification.psd1' -Value '@{ Commands = @(@{ Name = ''Invoke-Example'' }) }'

        { Build-ContainerModule -Specification './Specification.psd1' } | Should -Not -Throw
    }

    It 'allows a valid parameter array' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{ Name = 'Path'; Type = 'string'; Mandatory = $true }
                @{ Name = 'Force'; Type = 'switch' }
            )
        }
    )
}
'@

        { Build-ContainerModule -Specification './Specification.psd1' } | Should -Not -Throw
    }

    It 'requires Parameters to be an array' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @{ Name = 'Path'; Type = 'string' } }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Parameters' property for command 'Invoke-Example' must be an array*"
    }

    It 'requires each parameter to be an object' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @('Path') }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*Parameter at index 0*must be an object*'
    }

    It 'requires each parameter to have a non-empty string name' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = ''; Type = 'string' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Name'*"
    }

    It 'requires each parameter to have a non-empty string type' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Path' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Type'*"
    }

    It 'requires Mandatory to be Boolean when specified' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Path'; Type = 'string'; Mandatory = 'yes' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Mandatory' property*must be Boolean*"
    }

    It 'rejects case-insensitive duplicate parameter names within a command' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{ Name = 'Path'; Type = 'string' }
                @{ Name = 'path'; Type = 'string' }
            )
        }
    )
}
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*defined more than once*'
    }

    It 'requires a valid PowerShell parameter identifier' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'bad-name'; Type = 'string' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*is not a valid PowerShell identifier*'
    }

    It 'requires a supported PowerShell type name' {
        Set-Content -LiteralPath './Specification.psd1' -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string]; Write-Host bad; [string' }) }) }
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*is not a supported PowerShell type name*'
    }
}

Describe 'Container module mapping validation' {
    It 'allows a valid mappings array' {
        $specificationPath = Join-Path $TestDrive 'ValidMappings.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{
            Name = 'Invoke-Example'
            Parameters = @(
                @{
                    Name = 'Message'
                    Type = 'string'
                    Mappings = @(
                        @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
                        @{ Type = 'Argument'; Name = '--message' }
                    )
                }
            )
        }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'requires Mappings to be an array' {
        $specificationPath = Join-Path $TestDrive 'ScalarMappings.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @{ Type = 'Environment' } }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Mappings' property*must be an array*"
    }

    It 'requires each mapping to be an object' {
        $specificationPath = Join-Path $TestDrive 'ScalarMapping.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @('Environment') }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*Mapping at index 0*must be an object*'
    }

    It 'requires each mapping to have a non-empty string type' {
        $specificationPath = Join-Path $TestDrive 'MissingMappingType.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(@{ Name = 'EXAMPLE_MESSAGE' }) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must define a non-empty string 'Type'*"
    }

    It 'rejects unsupported mapping types' {
        $specificationPath = Join-Path $TestDrive 'UnsupportedMapping.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(
    @{ Name = 'Value'; Type = 'string'; Mappings = @(@{ Type = 'CustomRuntimeBehavior' }) }
) }) }
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*Mapping type 'CustomRuntimeBehavior'*is not supported*"
    }
}

Describe 'Container module object identities' {
    It 'normalizes root, command, and parameter IDs into model metadata' {
        $specificationPath = Join-Path $TestDrive 'Identities.psd1'
        $outputPath = Join-Path $TestDrive 'identity-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Id = 'module.example'
    Commands = @(@{
        Id = 'command.example'
        Name = 'Invoke-Example'
        Parameters = @(@{ Id = 'parameter.value'; Name = 'Value'; Type = 'string' })
    })
}
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $metadata = Get-Content -LiteralPath (Join-Path $outputPath 'Metadata/model.json') -Raw | ConvertFrom-Json

        $model.Id | Should -Be 'module.example'
        $model.Commands[0].Id | Should -Be 'command.example'
        $model.Commands[0].Parameters[0].Id | Should -Be 'parameter.value'
        $metadata.Id | Should -Be 'module.example'
    }

    It 'requires IDs to use the supported identifier syntax' {
        $specificationPath = Join-Path $TestDrive 'InvalidIdentity.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ Commands = @(@{ Id = 'command example'; Name = 'Invoke-Example' }) }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Id' property for command*"
    }

    It 'requires IDs to be globally unique without regard to case' {
        $specificationPath = Join-Path $TestDrive 'DuplicateIdentity.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Id = 'shared.identity'
    Commands = @(@{
        Name = 'Invoke-Example'
        Parameters = @(@{ Id = 'SHARED.IDENTITY'; Name = 'Value'; Type = 'string' })
    })
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*Id 'SHARED.IDENTITY'*defined more than once*"
    }
}

Describe 'Named mapping validation' {
    It 'allows named Argument and Environment mappings' {
        $specificationPath = Join-Path $TestDrive 'NamedMappings.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{
                Name = 'Message'
                Type = 'string'
                Mappings = @(
                    @{ Type = 'Argument'; Name = '--message' }
                    @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
                )
            }
        ) }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'requires an Argument mapping name' {
        $specificationPath = Join-Path $TestDrive 'UnnamedArgument.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(@{ Type = 'Argument' }) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Name' property for Argument mapping*must be a non-empty string*"
    }

    It 'requires an Environment mapping name' {
        $specificationPath = Join-Path $TestDrive 'UnnamedEnvironment.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(@{ Type = 'Environment'; Name = ' ' }) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Name' property for Environment mapping*must be a non-empty string*"
    }
}

Describe 'Mount mapping validation' {
    It 'allows a Mount mapping with a target and access mode' {
        $specificationPath = Join-Path $TestDrive 'ValidMount.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{
                Name = 'Repository'
                Type = 'DirectoryInfo'
                Mappings = @(@{ Type = 'Mount'; Target = '/repository'; Access = 'ReadOnly' })
            }
        ) }
    )
}
'@

        Test-ContainerModuleSpecification -Specification $specificationPath | Should -BeTrue
    }

    It 'requires a Mount mapping target' {
        $specificationPath = Join-Path $TestDrive 'MissingMountTarget.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mappings = @(
                @{ Type = 'Mount'; Access = 'ReadOnly' }
            ) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Target' property for Mount mapping*must be a non-empty string*"
    }

    It 'requires a Mount mapping access mode' {
        $specificationPath = Join-Path $TestDrive 'MissingMountAccess.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mappings = @(
                @{ Type = 'Mount'; Target = '/repository'; Access = ' ' }
            ) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Access' property for Mount mapping*must be a non-empty string*"
    }

    It 'rejects an unsupported Mount mapping access mode' {
        $specificationPath = Join-Path $TestDrive 'InvalidMountAccess.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mappings = @(
                @{ Type = 'Mount'; Target = '/repository'; Access = 'OwnerOnly' }
            ) }
        ) }
    )
}
'@

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*must be 'ReadOnly' or 'ReadWrite'*"
    }
}

Describe 'Port and working-directory mappings' {
    It 'generates Docker publish and working-directory options before the image' {
        $specificationPath = Join-Path $TestDrive 'RuntimeMappings.psd1'
        $outputPath = Join-Path $TestDrive 'runtime-mapping-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'RuntimeMappingExample'
    ContainerImage = 'example/runtime-tool'
    Commands = @(@{ Name = 'Invoke-RuntimeMappingExample'; Parameters = @(
        @{ Name = 'HostPort'; Type = 'int'; Mappings = @(
            @{ Type = 'Port'; ContainerPort = 8080; Protocol = 'udp' }
        ) }
        @{ Name = 'ContainerPath'; Type = 'string'; Mappings = @(
            @{ Type = 'WorkingDirectory' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'RuntimeMappingExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        try {
            Invoke-RuntimeMappingExample -HostPort 9000 -ContainerPath '/workspace'

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--publish', '9000:8080/udp',
                '--workdir', '/workspace', 'example/runtime-tool'
            )
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects invalid bound runtime values before calling Docker' {
        $specificationPath = Join-Path $TestDrive 'RuntimeValues.psd1'
        $outputPath = Join-Path $TestDrive 'runtime-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'RuntimeValueExample'
    Commands = @(@{ Name = 'Invoke-RuntimeValueExample'; Parameters = @(
        @{ Name = 'HostPort'; Type = 'int'; Mappings = @(
            @{ Type = 'Port'; ContainerPort = 80 }
        ) }
        @{ Name = 'ContainerPath'; Type = 'string'; Mappings = @(
            @{ Type = 'WorkingDirectory' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'RuntimeValueExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-RuntimeValueExample -HostPort 70000 } | Should -Throw -ExceptionType ([System.ArgumentOutOfRangeException])
            { Invoke-RuntimeValueExample -ContainerPath ' ' } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed runtime mapping definitions' {
        $invalidPortPath = Join-Path $TestDrive 'InvalidPort.psd1'
        $invalidProtocolPath = Join-Path $TestDrive 'InvalidProtocol.psd1'
        $invalidWorkdirTypePath = Join-Path $TestDrive 'InvalidWorkdirType.psd1'
        $duplicateWorkdirPath = Join-Path $TestDrive 'DuplicateWorkdir.psd1'
        Set-Content $invalidPortPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Port'; Type = 'int'; Mappings = @(@{ Type = 'Port'; ContainerPort = 70000 }) }) }) }"
        Set-Content $invalidProtocolPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Port'; Type = 'int'; Mappings = @(@{ Type = 'Port'; ContainerPort = 80; Protocol = 'sctp' }) }) }) }"
        Set-Content $invalidWorkdirTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Path'; Type = 'DirectoryInfo'; Mappings = @(@{ Type = 'WorkingDirectory' }) }) }) }"
        Set-Content $duplicateWorkdirPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'One'; Type = 'string'; Mappings = @(@{ Type = 'WorkingDirectory' }) }, @{ Name = 'Two'; Type = 'string'; Mappings = @(@{ Type = 'WorkingDirectory' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidPortPath } | Should -Throw -ExpectedMessage "*'ContainerPort'*1 through 65535*"
        { Test-ContainerModuleSpecification $invalidProtocolPath } | Should -Throw -ExpectedMessage "*'Protocol'*'tcp' or 'udp'*"
        { Test-ContainerModuleSpecification $invalidWorkdirTypePath } | Should -Throw -ExpectedMessage "*WorkingDirectory*must use type 'string'*"
        { Test-ContainerModuleSpecification $duplicateWorkdirPath } | Should -Throw -ExpectedMessage '*at most one WorkingDirectory*'
    }
}

Describe 'Volume and runtime-option mappings' {
    It 'generates named volume mounts and repeated pre-image runtime options' {
        $specificationPath = Join-Path $TestDrive 'VolumeOptions.psd1'
        $outputPath = Join-Path $TestDrive 'volume-option-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'VolumeOptionExample'
    ContainerImage = 'example/volume-tool'
    Commands = @(@{ Name = 'Invoke-VolumeOptionExample'; Parameters = @(
        @{ Name = 'Cache'; Type = 'string'; Mappings = @(
            @{ Type = 'Volume'; Target = '/cache'; Access = 'ReadOnly' }
        ) }
        @{ Name = 'Labels'; Type = 'string[]'; Mappings = @(
            @{ Type = 'RuntimeOption'; Name = '--label' }
        ) }
        @{ Name = 'Privileged'; Type = 'switch'; Mappings = @(
            @{ Type = 'RuntimeOption'; Name = '--privileged' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'VolumeOptionExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        try {
            Invoke-VolumeOptionExample -Cache 'build-cache' -Labels @('team=dev', 'stage=test') -Privileged

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--mount', 'type=volume,source=build-cache,target=/cache,readonly',
                '--label', 'team=dev', '--label', 'stage=test', '--privileged',
                'example/volume-tool'
            )
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects an unsafe bound Docker volume name before invocation' {
        $specificationPath = Join-Path $TestDrive 'VolumeValue.psd1'
        $outputPath = Join-Path $TestDrive 'volume-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'VolumeValueExample'; Commands = @(@{ Name = 'Invoke-VolumeValueExample'; Parameters = @(
    @{ Name = 'Cache'; Type = 'string'; Mappings = @(
        @{ Type = 'Volume'; Target = '/cache'; Access = 'ReadWrite' }
    ) }
) }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'VolumeValueExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-VolumeValueExample -Cache '../unsafe' } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed volume and runtime-option definitions' {
        $invalidVolumeTypePath = Join-Path $TestDrive 'InvalidVolumeType.psd1'
        $invalidVolumeTargetPath = Join-Path $TestDrive 'InvalidVolumeTarget.psd1'
        $invalidVolumeAccessPath = Join-Path $TestDrive 'InvalidVolumeAccess.psd1'
        $invalidOptionPath = Join-Path $TestDrive 'InvalidRuntimeOption.psd1'
        Set-Content $invalidVolumeTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Volume'; Type = 'int'; Mappings = @(@{ Type = 'Volume'; Target = '/cache'; Access = 'ReadOnly' }) }) }) }"
        Set-Content $invalidVolumeTargetPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Volume'; Type = 'string'; Mappings = @(@{ Type = 'Volume'; Target = 'cache'; Access = 'ReadOnly' }) }) }) }"
        Set-Content $invalidVolumeAccessPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Volume'; Type = 'string'; Mappings = @(@{ Type = 'Volume'; Target = '/cache'; Access = 'OwnerOnly' }) }) }) }"
        Set-Content $invalidOptionPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Network'; Type = 'string'; Mappings = @(@{ Type = 'RuntimeOption'; Name = '-n' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidVolumeTypePath } | Should -Throw -ExpectedMessage "*Volume*mapping*must use type 'string'*"
        { Test-ContainerModuleSpecification $invalidVolumeTargetPath } | Should -Throw -ExpectedMessage "*'Target'*absolute container path*"
        { Test-ContainerModuleSpecification $invalidVolumeAccessPath } | Should -Throw -ExpectedMessage "*'Access'*'ReadOnly' or 'ReadWrite'*"
        { Test-ContainerModuleSpecification $invalidOptionPath } | Should -Throw -ExpectedMessage "*'Name'*RuntimeOption*beginning with '--'*"
    }
}

Describe 'Device and GPU mappings' {
    It 'generates device passthrough and GPU options before the image' {
        $specificationPath = Join-Path $TestDrive 'AcceleratorMappings.psd1'
        $outputPath = Join-Path $TestDrive 'accelerator-output'
        $devicePath = Join-Path $TestDrive 'render-device'
        Set-Content -LiteralPath $devicePath -Value ''
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'AcceleratorExample'
    ContainerImage = 'example/accelerator-tool'
    Commands = @(@{ Name = 'Invoke-AcceleratorExample'; Parameters = @(
        @{ Name = 'Device'; Type = 'FileInfo'; Mappings = @(
            @{ Type = 'Device'; Target = '/dev/render'; Permissions = 'rw' }
        ) }
        @{ Name = 'SamePathDevice'; Type = 'FileInfo'; Mappings = @(
            @{ Type = 'Device'; Permissions = 'r' }
        ) }
        @{ Name = 'Gpu'; Type = 'string'; Mappings = @(
            @{ Type = 'Gpu' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'AcceleratorExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        try {
            Invoke-AcceleratorExample -Device $devicePath -SamePathDevice $devicePath -Gpu 'device=0,1'

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--device', ([System.IO.Path]::GetFullPath($devicePath) + ':/dev/render:rw'),
                '--device', ([System.IO.Path]::GetFullPath($devicePath) + ':' + [System.IO.Path]::GetFullPath($devicePath) + ':r'),
                '--gpus', 'device=0,1', 'example/accelerator-tool'
            )
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects an unsafe GPU selection before invoking Docker' {
        $specificationPath = Join-Path $TestDrive 'GpuValue.psd1'
        $outputPath = Join-Path $TestDrive 'gpu-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'GpuValueExample'; Commands = @(@{ Name = 'Invoke-GpuValueExample'; Parameters = @(
    @{ Name = 'Gpu'; Type = 'string'; Mappings = @(@{ Type = 'Gpu' }) }
) }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'GpuValueExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-GpuValueExample -Gpu '--privileged' } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed device and GPU mapping definitions' {
        $invalidDeviceTypePath = Join-Path $TestDrive 'InvalidDeviceType.psd1'
        $invalidDeviceTargetPath = Join-Path $TestDrive 'InvalidDeviceTarget.psd1'
        $invalidPermissionsPath = Join-Path $TestDrive 'InvalidDevicePermissions.psd1'
        $invalidGpuTypePath = Join-Path $TestDrive 'InvalidGpuType.psd1'
        Set-Content $invalidDeviceTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Device'; Type = 'int'; Mappings = @(@{ Type = 'Device' }) }) }) }"
        Set-Content $invalidDeviceTargetPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Device'; Type = 'string'; Mappings = @(@{ Type = 'Device'; Target = 'dev/render' }) }) }) }"
        Set-Content $invalidPermissionsPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Device'; Type = 'string'; Mappings = @(@{ Type = 'Device'; Permissions = 'wr' }) }) }) }"
        Set-Content $invalidGpuTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Gpu'; Type = 'int'; Mappings = @(@{ Type = 'Gpu' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidDeviceTypePath } | Should -Throw -ExpectedMessage "*Device*mapping*must use type 'string' or 'FileInfo'*"
        { Test-ContainerModuleSpecification $invalidDeviceTargetPath } | Should -Throw -ExpectedMessage "*'Target'*Device mapping*absolute container path*"
        { Test-ContainerModuleSpecification $invalidPermissionsPath } | Should -Throw -ExpectedMessage "*'Permissions'*ordered combination*"
        { Test-ContainerModuleSpecification $invalidGpuTypePath } | Should -Throw -ExpectedMessage "*Gpu*mapping*must use type 'string'*"
    }
}

Describe 'Resource limit and secret mappings' {
    It 'generates culture-invariant resource limits and read-only secret mounts' {
        $specificationPath = Join-Path $TestDrive 'Resources.psd1'
        $outputPath = Join-Path $TestDrive 'resource-output'
        $secretPath = Join-Path $TestDrive 'api-token.txt'
        Set-Content -LiteralPath $secretPath -Value 'secret-value'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ResourceExample'
    ContainerImage = 'example/resource-tool'
    Commands = @(@{ Name = 'Invoke-ResourceExample'; Parameters = @(
        @{ Name = 'Memory'; Type = 'string'; Mappings = @(
            @{ Type = 'ResourceLimit'; Resource = 'Memory' }
        ) }
        @{ Name = 'Cpus'; Type = 'double'; Mappings = @(
            @{ Type = 'ResourceLimit'; Resource = 'Cpus' }
        ) }
        @{ Name = 'Secret'; Type = 'FileInfo'; Mappings = @(
            @{ Type = 'Secret'; Name = 'api-token' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'ResourceExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args); $global:LASTEXITCODE = 0 }
        $originalCulture = [System.Globalization.CultureInfo]::CurrentCulture
        try {
            [System.Globalization.CultureInfo]::CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
            Invoke-ResourceExample -Memory '512m' -Cpus 1.5 -Secret $secretPath

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '--memory', '512m', '--cpus', '1.5', '--mount',
                ('type=bind,source=' + [System.IO.Path]::GetFullPath($secretPath) + ',target=/run/secrets/api-token,readonly'),
                'example/resource-tool'
            )
        }
        finally {
            [System.Globalization.CultureInfo]::CurrentCulture = $originalCulture
            Remove-Item Function:\docker -Force
            Remove-Variable capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects invalid resource values and missing secret files before Docker' {
        $specificationPath = Join-Path $TestDrive 'ResourceValues.psd1'
        $outputPath = Join-Path $TestDrive 'resource-value-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'ResourceValueExample'; Commands = @(@{ Name = 'Invoke-ResourceValueExample'; Parameters = @(
    @{ Name = 'Memory'; Type = 'string'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Memory' }) }
    @{ Name = 'Cpus'; Type = 'double'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Cpus' }) }
    @{ Name = 'Secret'; Type = 'FileInfo'; Mappings = @(@{ Type = 'Secret'; Name = 'token' }) }
) }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'ResourceValueExample.psd1') -Force -PassThru
        $commaSecretPath = Join-Path $TestDrive 'unsafe,secret'
        Set-Content -LiteralPath $commaSecretPath -Value 'secret'
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            { Invoke-ResourceValueExample -Memory 'unlimited' } | Should -Throw -ExceptionType ([System.ArgumentException])
            { Invoke-ResourceValueExample -Cpus 0 } | Should -Throw -ExceptionType ([System.ArgumentOutOfRangeException])
            { Invoke-ResourceValueExample -Secret (Join-Path $TestDrive 'missing.secret') } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
            { Invoke-ResourceValueExample -Secret $commaSecretPath } | Should -Throw -ExceptionType ([System.ArgumentException])
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item Function:\docker -Force
            Remove-Variable dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed resource limit and secret definitions' {
        $invalidResourcePath = Join-Path $TestDrive 'InvalidResource.psd1'
        $invalidMemoryTypePath = Join-Path $TestDrive 'InvalidMemoryType.psd1'
        $invalidCpuTypePath = Join-Path $TestDrive 'InvalidCpuType.psd1'
        $invalidSecretTypePath = Join-Path $TestDrive 'InvalidSecretType.psd1'
        $invalidSecretNamePath = Join-Path $TestDrive 'InvalidSecretName.psd1'
        $invalidSecretTargetPath = Join-Path $TestDrive 'InvalidSecretTarget.psd1'
        Set-Content $invalidResourcePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Limit'; Type = 'string'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Disk' }) }) }) }"
        Set-Content $invalidMemoryTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Memory'; Type = 'int'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Memory' }) }) }) }"
        Set-Content $invalidCpuTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Cpus'; Type = 'string'; Mappings = @(@{ Type = 'ResourceLimit'; Resource = 'Cpus' }) }) }) }"
        Set-Content $invalidSecretTypePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Secret'; Type = 'int'; Mappings = @(@{ Type = 'Secret'; Name = 'token' }) }) }) }"
        Set-Content $invalidSecretNamePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Secret'; Type = 'string'; Mappings = @(@{ Type = 'Secret'; Name = '../token' }) }) }) }"
        Set-Content $invalidSecretTargetPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Secret'; Type = 'string'; Mappings = @(@{ Type = 'Secret'; Name = 'token'; Target = 'run/token' }) }) }) }"

        { Test-ContainerModuleSpecification $invalidResourcePath } | Should -Throw -ExpectedMessage "*'Resource'*'Memory' or 'Cpus'*"
        { Test-ContainerModuleSpecification $invalidMemoryTypePath } | Should -Throw -ExpectedMessage "*Memory ResourceLimit*must use type 'string'*"
        { Test-ContainerModuleSpecification $invalidCpuTypePath } | Should -Throw -ExpectedMessage "*Cpus ResourceLimit*numeric type*"
        { Test-ContainerModuleSpecification $invalidSecretTypePath } | Should -Throw -ExpectedMessage "*Secret*mapping*must use type 'string' or 'FileInfo'*"
        { Test-ContainerModuleSpecification $invalidSecretNamePath } | Should -Throw -ExpectedMessage "*'Name'*Secret mapping*safe non-empty file name*"
        { Test-ContainerModuleSpecification $invalidSecretTargetPath } | Should -Throw -ExpectedMessage "*'Target'*Secret mapping*absolute container path*"
    }
}

Describe 'Static argument completion' {
    It 'normalizes, persists, renders, and returns static completion values' {
        $specificationPath = Join-Path $TestDrive 'Completions.psd1'
        $outputPath = Join-Path $TestDrive 'completion-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'CompletionExample'
    Commands = @(@{ Name = 'Invoke-CompletionExample'; Parameters = @(
        @{ Name = 'Mode'; Type = 'string'; Completions = @(
            @{ Type = 'Static'; Values = @('Build', 'Benchmark') }
            @{ Type = 'Static'; Values = @('Test') }
        ) }
    ) })
}
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $source = Get-Content -LiteralPath (Join-Path $outputPath 'Public' 'Invoke-CompletionExample.ps1') -Raw
        $metadata = Get-Content -LiteralPath (Join-Path $outputPath 'Metadata/model.json') -Raw | ConvertFrom-Json
        $module = Import-Module (Join-Path $outputPath 'CompletionExample.psd1') -Force -PassThru
        try {
            $inputText = 'Invoke-CompletionExample -Mode B'
            $matches = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $inputText, $inputText.Length, $null
            ).CompletionMatches.CompletionText

            $model.Commands[0].Parameters[0].Completions.Count | Should -Be 2
            $model.Commands[0].Parameters[0].Completions[0].Values | Should -Be @('Build', 'Benchmark')
            $metadata.Commands[0].Parameters[0].Completions[1].Values | Should -Be @('Test')
            $source | Should -Match "\[ArgumentCompletions\('Build', 'Benchmark', 'Test'\)\]"
            $matches | Should -Be @('Build', 'Benchmark')
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed and duplicate static completion definitions' {
        $scalarPath = Join-Path $TestDrive 'ScalarCompletions.psd1'
        $unsupportedPath = Join-Path $TestDrive 'UnsupportedCompletion.psd1'
        $emptyValuesPath = Join-Path $TestDrive 'EmptyCompletionValues.psd1'
        $duplicatePath = Join-Path $TestDrive 'DuplicateCompletionValues.psd1'
        Set-Content $scalarPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @{ Type = 'Static'; Values = @('One') } }) }) }"
        Set-Content $unsupportedPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @(@{ Type = 'Script' }) }) }) }"
        Set-Content $emptyValuesPath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @(@{ Type = 'Static'; Values = @() }) }) }) }"
        Set-Content $duplicatePath "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Completions = @(@{ Type = 'Static'; Values = @('One', 'one') }) }) }) }"

        { Test-ContainerModuleSpecification $scalarPath } | Should -Throw -ExpectedMessage "*'Completions'*must be an array*"
        { Test-ContainerModuleSpecification $unsupportedPath } | Should -Throw -ExpectedMessage "*Completion type 'Script'*not supported*"
        { Test-ContainerModuleSpecification $emptyValuesPath } | Should -Throw -ExpectedMessage "*Static completion*non-empty string array*"
        { Test-ContainerModuleSpecification $duplicatePath } | Should -Throw -ExpectedMessage "*Completion value 'one'*defined more than once*"
    }
}

Describe 'Parameter validation attributes' {
    It 'normalizes and renders supported native validation attributes' {
        $specificationPath = Join-Path $TestDrive 'Validations.psd1'
        $outputPath = Join-Path $TestDrive 'validation-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ValidationExample'
    Commands = @(@{ Name = 'Invoke-ValidationExample'; Parameters = @(
        @{ Name = 'Task'; Type = 'string'; Validations = @(
            @{ Type = 'ValidateSet'; Values = @('Build', 'Test') }
            @{ Type = 'ValidatePattern'; Pattern = '^[A-Z][a-z]+$' }
        ) }
        @{ Name = 'Count'; Type = 'int'; Validations = @(
            @{ Type = 'ValidateRange'; Minimum = 1; Maximum = 10 }
        ) }
    ) })
}
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $source = Get-Content -LiteralPath (Join-Path $outputPath 'Public' 'Invoke-ValidationExample.ps1') -Raw
        $module = Import-Module (Join-Path $outputPath 'ValidationExample.psd1') -Force -PassThru
        try {
            $model.Commands[0].Parameters[0].Validations.Count | Should -Be 2
            $model.Commands[0].Parameters[0].Validations[0].Type | Should -Be 'ValidateSet'
            $source | Should -Match "\[ValidateSet\('Build', 'Test'\)\]"
            $source | Should -Match '\[ValidatePattern\(''\^\[A-Z\]\[a-z\]\+\$''\)\]'
            $source | Should -Match '\[ValidateRange\(1, 10\)\]'
            { Invoke-ValidationExample -Task Deploy -Count 5 } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
            { Invoke-ValidationExample -Task Build -Count 11 } | Should -Throw -ExceptionType ([System.Management.Automation.ParameterBindingException])
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'rejects malformed validation definitions' {
        $unsupportedPath = Join-Path $TestDrive 'UnsupportedValidation.psd1'
        $emptySetPath = Join-Path $TestDrive 'EmptySet.psd1'
        $reversedRangePath = Join-Path $TestDrive 'ReversedRange.psd1'
        $invalidPatternPath = Join-Path $TestDrive 'InvalidPattern.psd1'
        Set-Content -LiteralPath $unsupportedPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Validations = @(@{ Type = 'ValidateScript' }) }) }) }"
        Set-Content -LiteralPath $emptySetPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Validations = @(@{ Type = 'ValidateSet'; Values = @() }) }) }) }"
        Set-Content -LiteralPath $reversedRangePath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'int'; Validations = @(@{ Type = 'ValidateRange'; Minimum = 10; Maximum = 1 }) }) }) }"
        Set-Content -LiteralPath $invalidPatternPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(@{ Name = 'Value'; Type = 'string'; Validations = @(@{ Type = 'ValidatePattern'; Pattern = '[' }) }) }) }"

        { Test-ContainerModuleSpecification $unsupportedPath } | Should -Throw -ExpectedMessage '*not supported*'
        { Test-ContainerModuleSpecification $emptySetPath } | Should -Throw -ExpectedMessage '*non-empty string array*'
        { Test-ContainerModuleSpecification $reversedRangePath } | Should -Throw -ExpectedMessage '*ascending order*'
        { Test-ContainerModuleSpecification $invalidPatternPath } | Should -Throw -ExpectedMessage '*invalid regular expression*'
    }
}

Describe 'Container module object model' {
    It 'normalizes a specification without commands to an empty collection' {
        InModuleScope SubZeroDev.ContainerPSGenerator {
            $model = ConvertTo-ContainerModuleModel -Specification @{}

            $model.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model'
            $model.ModuleName | Should -Be 'PSModule'
            $model.ModuleVersion | Should -Be '0.1.0'
            $model.ContainerImage | Should -Be 'PSModule'
            [object]::ReferenceEquals($null, $model.Commands) | Should -BeFalse
            $model.Commands.Count | Should -Be 0
        }
    }

    It 'normalizes commands, parameters, and mappings' {
        InModuleScope SubZeroDev.ContainerPSGenerator {
            $definition = @{
                Commands = @(
                    @{
                        Id = 'command.example'
                        Name = 'Invoke-Example'
                        Description = 'Runs the example.'
                        Parameters = @(
                            @{
                                Id = 'parameter.repository'
                                Name = 'Repository'
                                Type = 'DirectoryInfo'
                                Mappings = @(
                                    @{ Type = 'Mount'; Target = '/repository'; Access = 'ReadOnly' }
                                )
                            }
                        )
                    }
                )
            }

            $model = ConvertTo-ContainerModuleModel -Specification $definition
            $command = $model.Commands[0]
            $parameter = $command.Parameters[0]
            $mapping = $parameter.Mappings[0]

            $command.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model.Command'
            $command.Id | Should -Be 'command.example'
            $command.Name | Should -Be 'Invoke-Example'
            $command.Description | Should -Be 'Runs the example.'
            $parameter.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model.Parameter'
            $parameter.Id | Should -Be 'parameter.repository'
            $parameter.Type | Should -Be 'DirectoryInfo'
            $parameter.Mandatory | Should -BeFalse
            $mapping.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model.Mapping'
            $mapping.Type | Should -Be 'Mount'
            $mapping.Definition.Target | Should -Be '/repository'
            [object]::ReferenceEquals($model.Definition, $definition) | Should -BeTrue
        }
    }
}

Describe 'Get-ContainerModuleModel' {
    It 'returns a validated normalized model' {
        $specificationPath = Join-Path $TestDrive 'Model.psd1'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @() }) }
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath

        $model.PSObject.TypeNames | Should -Contain 'SubZeroDev.ContainerPSGenerator.Model'
        $model.Commands[0].Name | Should -Be 'Invoke-Example'
    }
}

Describe 'Container module metadata generation' {
    It 'writes deterministic normalized JSON using UTF-8 without BOM' {
        $specificationPath = Join-Path $TestDrive 'Metadata.psd1'
        $outputPath = Join-Path $TestDrive 'metadata-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mappings = @(
                @{ Type = 'Environment'; Name = 'EXAMPLE_MESSAGE' }
            ) }
        ) }
    )
}
'@

        $artifact = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $firstContent = [System.IO.File]::ReadAllText($artifact.FullName)
        $firstBytes = [System.IO.File]::ReadAllBytes($artifact.FullName)
        $metadata = $firstContent | ConvertFrom-Json

        $metadata.SchemaVersion | Should -Be 1
        $metadata.Commands[0].Parameters[0].Mappings[0].Name | Should -Be 'EXAMPLE_MESSAGE'
        $firstContent | Should -Not -Match "`r`n"
        $firstBytes[0] | Should -Not -Be 0xEF

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        [System.IO.File]::ReadAllText($artifact.FullName) | Should -BeExactly $firstContent
    }
}

Describe 'Container module command source generation' {
    It 'writes parseable deterministic command source with declared parameters' {
        $specificationPath = Join-Path $TestDrive 'CommandSource.psd1'
        $outputPath = Join-Path $TestDrive 'command-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @(
            @{ Name = 'Repository'; Type = 'DirectoryInfo'; Mandatory = $true }
            @{ Name = 'Tags'; Type = 'string[]' }
        ) }
    )
}
'@

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $sourcePath = Join-Path $outputPath 'Public' 'Invoke-Example.ps1'
        $firstContent = [System.IO.File]::ReadAllText($sourcePath)
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $sourcePath,
            [ref] $tokens,
            [ref] $parseErrors
        )

        $parseErrors | Should -BeNullOrEmpty
        $firstContent | Should -Match 'function Invoke-Example'
        $firstContent | Should -Match '\[Parameter\(Mandatory = \$true\)\]'
        $firstContent | Should -Match '\[System\.IO\.DirectoryInfo\] \$Repository,'
        $firstContent | Should -Match '\[string\[\]\] \$Tags'
        $firstContent | Should -Not -Match "`r`n"

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        [System.IO.File]::ReadAllText($sourcePath) | Should -BeExactly $firstContent
    }
}

Describe 'Container module loader generation' {
    It 'writes an importable loader that exports generated commands' {
        $specificationPath = Join-Path $TestDrive 'Loader.psd1'
        $outputPath = Join-Path $TestDrive 'loader-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ExampleContainer'
    ModuleVersion = '1.2.3'
    Commands = @(
        @{ Name = 'Invoke-Example'; Parameters = @() }
    )
}
'@

        $null = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $loaderPath = Join-Path $outputPath 'ExampleContainer.psm1'
        $module = Import-Module $loaderPath -Force -PassThru

        try {
            $module.Name | Should -Be 'ExampleContainer'
            Get-Command Invoke-Example -Module ExampleContainer | Should -Not -BeNullOrEmpty
        }
        finally {
            Remove-Module ExampleContainer -Force
        }
    }
}

Describe 'Container module manifest generation' {
    It 'writes a valid manifest that imports and exports generated commands' {
        $specificationPath = Join-Path $TestDrive 'Manifest.psd1'
        $outputPath = Join-Path $TestDrive 'manifest-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'ManifestExample'
    ModuleVersion = '2.3.4'
    Commands = @(
        @{ Name = 'Invoke-ManifestExample'; Parameters = @() }
    )
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null

        $generatedManifestPath = Join-Path $outputPath 'ManifestExample.psd1'
        $manifest = Test-ModuleManifest -Path $generatedManifestPath -ErrorAction Stop
        $module = Import-Module $generatedManifestPath -Force -PassThru
        try {
            $manifest.Version.ToString() | Should -Be '2.3.4'
            $module.ExportedFunctions.Keys | Should -Contain 'Invoke-ManifestExample'
        }
        finally {
            Remove-Module ManifestExample -Force
        }
    }

    It 'writes deterministic manifest content' {
        $specificationPath = Join-Path $TestDrive 'DeterministicManifest.psd1'
        $outputPath = Join-Path $TestDrive 'deterministic-manifest-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'StableExample'; Commands = @(@{ Name = 'Get-StableExample' }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $first = [System.IO.File]::ReadAllBytes((Join-Path $outputPath 'StableExample.psd1'))
        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $second = [System.IO.File]::ReadAllBytes((Join-Path $outputPath 'StableExample.psd1'))

        [Convert]::ToHexString($second) | Should -Be ([Convert]::ToHexString($first))
    }
}

Describe 'Container module output reset' {
    It 'removes stale artifacts before generating the current module' {
        $specificationPath = Join-Path $TestDrive 'Reset.psd1'
        $outputPath = Join-Path $TestDrive 'reset-output'
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outputPath 'stale.txt') -Value 'old build'
        Set-Content -LiteralPath $specificationPath -Value '@{ Commands = @() }'

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null

        Test-Path -LiteralPath (Join-Path $outputPath 'stale.txt') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $outputPath 'PSModule.psd1') | Should -BeTrue
    }

    It 'preserves existing output when validation fails' {
        $specificationPath = Join-Path $TestDrive 'InvalidReset.psd1'
        $outputPath = Join-Path $TestDrive 'preserved-output'
        New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outputPath 'keep.txt') -Value 'keep me'
        Set-Content -LiteralPath $specificationPath -Value "@{ ModuleVersion = 'invalid' }"

        { Build-ContainerModule -Specification $specificationPath -Output $outputPath } | Should -Throw

        Test-Path -LiteralPath (Join-Path $outputPath 'keep.txt') | Should -BeTrue
    }
}

Describe 'Container runtime configuration' {
    It 'normalizes an explicit container image into the model and metadata' {
        $specificationPath = Join-Path $TestDrive 'Runtime.psd1'
        $outputPath = Join-Path $TestDrive 'runtime-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ContainerImage = 'ghcr.io/example/tool:1.2.3'; Commands = @() }
'@

        $model = Get-ContainerModuleModel -Specification $specificationPath
        $artifact = Build-ContainerModule -Specification $specificationPath -Output $outputPath
        $metadata = Get-Content -LiteralPath $artifact -Raw | ConvertFrom-Json

        $model.ContainerImage | Should -Be 'ghcr.io/example/tool:1.2.3'
        $metadata.ContainerImage | Should -Be 'ghcr.io/example/tool:1.2.3'
    }

    It 'rejects an unsafe container image reference' {
        $specificationPath = Join-Path $TestDrive 'UnsafeRuntime.psd1'
        Set-Content -LiteralPath $specificationPath -Value "@{ ContainerImage = 'bad image' }"

        { Test-ContainerModuleSpecification -Specification $specificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'ContainerImage' property must be*"
    }
}

Describe 'Docker runtime command generation' {
    It 'maps bound environment and argument parameters in Docker order' {
        $specificationPath = Join-Path $TestDrive 'DockerCommand.psd1'
        $outputPath = Join-Path $TestDrive 'docker-command-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'DockerExample'
    ContainerImage = 'ghcr.io/example/tool:latest'
    Commands = @(
        @{
            Name = 'Invoke-DockerExample'
            Parameters = @(
                @{ Name = 'Message'; Type = 'string'; Mappings = @(
                    @{ Type = 'Environment'; Name = 'TOOL_MESSAGE' }
                    @{ Type = 'Argument'; Name = '--message' }
                ) }
                @{ Name = 'VerboseOutput'; Type = 'switch'; Mappings = @(
                    @{ Type = 'Argument'; Name = '--verbose' }
                ) }
            )
        }
    )
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'DockerExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args) }
        try {
            Invoke-DockerExample -Message 'hello world' -VerboseOutput

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm', '-e', 'TOOL_MESSAGE=hello world',
                'ghcr.io/example/tool:latest', '--message', 'hello world', '--verbose'
            )
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'does not emit mappings for omitted optional parameters' {
        $specificationPath = Join-Path $TestDrive 'OptionalDockerCommand.psd1'
        $outputPath = Join-Path $TestDrive 'optional-docker-command-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'OptionalDockerExample'
    ContainerImage = 'example/tool'
    Commands = @(@{ Name = 'Invoke-OptionalDockerExample'; Parameters = @(
        @{ Name = 'Message'; Type = 'string'; Mappings = @(
            @{ Type = 'Argument'; Name = '--message' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'OptionalDockerExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args) }
        try {
            Invoke-OptionalDockerExample

            $global:capturedDockerArguments | Should -Be @('run', '--rm', 'example/tool')
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }
}

Describe 'Docker mount and error generation' {
    It 'maps read-only and read-write bind mounts before the image' {
        $specificationPath = Join-Path $TestDrive 'DockerMounts.psd1'
        $outputPath = Join-Path $TestDrive 'docker-mount-output'
        $readOnlyPath = Join-Path $TestDrive 'source-one'
        $readWritePath = Join-Path $TestDrive 'source-two'
        New-Item -Path $readOnlyPath -ItemType Directory -Force | Out-Null
        New-Item -Path $readWritePath -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'MountExample'
    ContainerImage = 'example/mount-tool'
    Commands = @(@{ Name = 'Invoke-MountExample'; Parameters = @(
        @{ Name = 'InputPath'; Type = 'DirectoryInfo'; Mappings = @(
            @{ Type = 'Mount'; Target = '/input'; Access = 'ReadOnly' }
        ) }
        @{ Name = 'OutputPath'; Type = 'DirectoryInfo'; Mappings = @(
            @{ Type = 'Mount'; Target = '/output'; Access = 'ReadWrite' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'MountExample.psd1') -Force -PassThru
        $global:capturedDockerArguments = $null
        function global:docker { $global:capturedDockerArguments = @($args) }
        try {
            Invoke-MountExample -InputPath $readOnlyPath -OutputPath $readWritePath

            $global:capturedDockerArguments | Should -Be @(
                'run', '--rm',
                '--mount', "type=bind,source=$([System.IO.Path]::GetFullPath($readOnlyPath)),target=/input,readonly",
                '--mount', "type=bind,source=$([System.IO.Path]::GetFullPath($readWritePath)),target=/output",
                'example/mount-tool'
            )
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name capturedDockerArguments -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'reports when Docker cannot be found' {
        $specificationPath = Join-Path $TestDrive 'MissingDocker.psd1'
        $outputPath = Join-Path $TestDrive 'missing-docker-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'MissingDockerExample'; Commands = @(@{ Name = 'Invoke-MissingDockerExample' }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'MissingDockerExample.psd1') -Force -PassThru
        $originalPath = $env:PATH
        try {
            $env:PATH = ''
            { Invoke-MissingDockerExample } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*Docker is required*not found on PATH*'
        }
        finally {
            $env:PATH = $originalPath
            Remove-Module $module -Force
        }
    }

    It 'reports an unsuccessful Docker invocation' {
        $specificationPath = Join-Path $TestDrive 'FailedDocker.psd1'
        $outputPath = Join-Path $TestDrive 'failed-docker-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{ ModuleName = 'FailedDockerExample'; Commands = @(@{ Name = 'Invoke-FailedDockerExample' }) }
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'FailedDockerExample.psd1') -Force -PassThru
        function global:docker { $global:LASTEXITCODE = 23 }
        try {
            { Invoke-FailedDockerExample -ErrorAction SilentlyContinue } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*Docker failed with exit code 23*'
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Module $module -Force
        }
    }
}

Describe 'Generated command help and preview' {
    It 'renders synopsis, description, notes, and structured examples' {
        $specificationPath = Join-Path $TestDrive 'RichHelp.psd1'
        $outputPath = Join-Path $TestDrive 'rich-help-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'RichHelpExample'
    Commands = @(@{
        Name = 'Invoke-RichHelpExample'
        Synopsis = 'Runs the documented example.'
        Description = 'Provides a longer explanation of the operation.'
        Notes = 'Docker must be available on PATH.'
        Examples = @(@{
            Code = "Invoke-RichHelpExample -WhatIf"
            Description = 'Previews the container invocation.'
        })
    })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'RichHelpExample.psd1') -Force -PassThru
        try {
            $help = Get-Help Invoke-RichHelpExample -Full

            $help.Synopsis | Should -Be 'Runs the documented example.'
            $help.Description.Text | Should -Be 'Provides a longer explanation of the operation.'
            $help.alertSet.alert.Text | Should -Be 'Docker must be available on PATH.'
            $help.Examples.Example[0].Code | Should -Be 'Invoke-RichHelpExample -WhatIf'
            @($help.Examples.Example[0].Remarks.Text).Where({ -not [string]::IsNullOrWhiteSpace($_) }) |
                Should -Be 'Previews the container invocation.'
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'renders command and parameter descriptions as help' {
        $specificationPath = Join-Path $TestDrive 'Help.psd1'
        $outputPath = Join-Path $TestDrive 'help-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'HelpExample'
    Commands = @(@{
        Name = 'Invoke-HelpExample'
        Description = 'Runs a documented container operation.'
        Parameters = @(@{
            Name = 'Message'
            Description = 'Message supplied to the container.'
            Type = 'string'
        })
    })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'HelpExample.psd1') -Force -PassThru
        try {
            $help = Get-Help Invoke-HelpExample -Full

            $help.Synopsis | Should -Be 'Runs a documented container operation.'
            $help.Parameters.Parameter.Where({ $_.Name -eq 'Message' }).Description.Text |
                Should -Be 'Message supplied to the container.'
        }
        finally {
            Remove-Module $module -Force
        }
    }

    It 'previews the Docker invocation without discovering or running Docker' {
        $specificationPath = Join-Path $TestDrive 'Preview.psd1'
        $outputPath = Join-Path $TestDrive 'preview-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'PreviewExample'
    ContainerImage = 'example/preview-tool'
    Commands = @(@{ Name = 'Invoke-PreviewExample'; Parameters = @(
        @{ Name = 'Message'; Type = 'string'; Mappings = @(
            @{ Type = 'Argument'; Name = '--message' }
        ) }
    ) })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $module = Import-Module (Join-Path $outputPath 'PreviewExample.psd1') -Force -PassThru
        $global:dockerWasInvoked = $false
        function global:docker { $global:dockerWasInvoked = $true }
        try {
            $command = Get-Command Invoke-PreviewExample
            Invoke-PreviewExample -Message 'hello' -WhatIf

            $command.Parameters.Keys | Should -Contain 'WhatIf'
            $global:dockerWasInvoked | Should -BeFalse
        }
        finally {
            Remove-Item -Path Function:\docker -Force
            Remove-Variable -Name dockerWasInvoked -Scope Global -Force
            Remove-Module $module -Force
        }
    }

    It 'requires descriptions to be non-empty strings when provided' {
        $commandSpecificationPath = Join-Path $TestDrive 'InvalidCommandHelp.psd1'
        $parameterSpecificationPath = Join-Path $TestDrive 'InvalidParameterHelp.psd1'
        Set-Content -LiteralPath $commandSpecificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Description = ' ' }) }
'@
        Set-Content -LiteralPath $parameterSpecificationPath -Value @'
@{ Commands = @(@{ Name = 'Invoke-Example'; Parameters = @(
    @{ Name = 'Message'; Type = 'string'; Description = 42 }
) }) }
'@

        { Test-ContainerModuleSpecification -Specification $commandSpecificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Description' property for command*"
        { Test-ContainerModuleSpecification -Specification $parameterSpecificationPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Description' property for parameter*"
    }

    It 'validates structured command help fields and examples' {
        $invalidSynopsisPath = Join-Path $TestDrive 'InvalidSynopsis.psd1'
        $scalarExamplesPath = Join-Path $TestDrive 'ScalarExamples.psd1'
        $invalidExamplePath = Join-Path $TestDrive 'InvalidExample.psd1'
        Set-Content -LiteralPath $invalidSynopsisPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Synopsis = ' ' }) }"
        Set-Content -LiteralPath $scalarExamplesPath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Examples = @{ Code = 'Invoke-Example'; Description = 'Runs it.' } }) }"
        Set-Content -LiteralPath $invalidExamplePath -Value "@{ Commands = @(@{ Name = 'Invoke-Example'; Examples = @(@{ Code = ' '; Description = 'Runs it.' }) }) }"

        { Test-ContainerModuleSpecification -Specification $invalidSynopsisPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Synopsis' property for command*"
        { Test-ContainerModuleSpecification -Specification $scalarExamplesPath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Examples' property for command*must be an array*"
        { Test-ContainerModuleSpecification -Specification $invalidExamplePath } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage "*'Code' property for example*must be a non-empty string*"
    }
}

Describe 'Generated Markdown command documentation' {
    It 'writes deterministic command references from the normalized help model' {
        $specificationPath = Join-Path $TestDrive 'MarkdownHelp.psd1'
        $outputPath = Join-Path $TestDrive 'markdown-help-output'
        Set-Content -LiteralPath $specificationPath -Value @'
@{
    ModuleName = 'MarkdownHelpExample'
    Commands = @(@{
        Name = 'Invoke-MarkdownHelpExample'
        Synopsis = 'Runs the **documented** operation.'
        Description = 'A longer Markdown description.'
        Notes = 'Requires Docker.'
        Examples = @(@{
            Code = "Invoke-MarkdownHelpExample -Message 'hello'"
            Description = 'Runs with a message.'
        })
        Parameters = @(
            @{ Name = 'Message'; Type = 'string'; Mandatory = $true; Description = 'Message to send.' }
            @{ Name = 'Count'; Type = 'int'; Description = 'Optional repeat count.' }
        )
    })
}
'@

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        $documentationPath = Join-Path $outputPath 'Documentation' 'Invoke-MarkdownHelpExample.md'
        $firstBytes = [System.IO.File]::ReadAllBytes($documentationPath)
        $markdown = [System.Text.Encoding]::UTF8.GetString($firstBytes)

        $markdown | Should -Match '^# Invoke-MarkdownHelpExample\n'
        $markdown | Should -Match 'Runs the \*\*documented\*\* operation\.'
        $markdown | Should -Match 'Invoke-MarkdownHelpExample -Message <string> \[-Count <int>\] \[<CommonParameters>\]'
        $markdown | Should -Match '### `-Message`\n\nType: `string`  \nRequired: Yes'
        $markdown | Should -Match "    Invoke-MarkdownHelpExample -Message 'hello'"
        $markdown | Should -Match '## Notes\n\nRequires Docker\.'
        $firstBytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null
        [System.IO.File]::ReadAllBytes($documentationPath) | Should -Be $firstBytes
    }

    It 'does not create a documentation directory when no commands exist' {
        $specificationPath = Join-Path $TestDrive 'NoDocumentation.psd1'
        $outputPath = Join-Path $TestDrive 'no-documentation-output'
        Set-Content -LiteralPath $specificationPath -Value '@{ ModuleName = ''NoDocumentationExample'' }'

        Build-ContainerModule -Specification $specificationPath -Output $outputPath | Out-Null

        Join-Path $outputPath 'Documentation' | Should -Not -Exist
    }
}

Describe 'Install-ContainerModule' {
    BeforeEach {
        $global:dockerCalls = [System.Collections.Generic.List[string]]::new()
        function global:Write-TestContainerModule {
            param ([string] $Path)
            Set-Content -LiteralPath (Join-Path $Path 'Example.psm1') -Value ''
            Set-Content -LiteralPath (Join-Path $Path 'Example.psd1') -Value @'
@{ RootModule = 'Example.psm1'; ModuleVersion = '1.0.0' }
'@
        }
    }

    AfterEach {
        if (Test-Path Function:\docker) {
            Remove-Item Function:\docker -Force
        }
        Remove-Variable -Name dockerCalls -Scope Global -Force -ErrorAction SilentlyContinue
        Remove-Item Function:\Write-TestContainerModule -Force -ErrorAction SilentlyContinue
    }

    It 'copies the embedded module and removes the temporary container' {
        $destination = Join-Path $TestDrive 'installed-module'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'create') { 'container-123' }
            if ($args[0] -eq 'cp') { Write-TestContainerModule -Path $args[2] }
        }

        $installedDirectory = Install-ContainerModule 'example/tool:1.0' -Destination $destination

        $installedDirectory.FullName | Should -Be ([System.IO.Path]::GetFullPath($destination))
        $global:dockerCalls[0] | Should -Be 'create example/tool:1.0'
        $global:dockerCalls[1] | Should -Match '^cp container-123:/PSModule/\. .+\.installed-module\.install-[a-f0-9]{32}$'
        $global:dockerCalls[2] | Should -Be 'rm --force container-123'
        Test-Path -LiteralPath (Join-Path $destination 'Example.psd1') | Should -BeTrue
    }

    It 'removes the temporary container when copying fails' {
        $destination = Join-Path $TestDrive 'failed-install'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            if ($args[0] -eq 'create') {
                $global:LASTEXITCODE = 0
                'container-failed-copy'
            }
            elseif ($args[0] -eq 'cp') {
                $global:LASTEXITCODE = 17
            }
            else {
                $global:LASTEXITCODE = 0
            }
        }

        { Install-ContainerModule 'example/tool:1.0' -Destination $destination } |
            Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*could not copy /PSModule*Exit code: 17*'

        $global:dockerCalls[-1] | Should -Be 'rm --force container-failed-copy'
    }

    It 'previews installation without calling Docker or creating the destination' {
        $destination = Join-Path $TestDrive 'preview-install'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
        }

        Install-ContainerModule 'example/tool:1.0' -Destination $destination -WhatIf

        $global:dockerCalls | Should -BeNullOrEmpty
        Test-Path -LiteralPath $destination | Should -BeFalse
    }

    It 'requires Force before replacing an existing destination' {
        $destination = Join-Path $TestDrive 'existing-install'
        New-Item -Path $destination -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'preserve'
        function global:docker { throw 'Docker should not be called.' }

        { Install-ContainerModule 'example/tool:1.0' -Destination $destination } |
            Should -Throw -ExceptionType ([System.IO.IOException]) -ExpectedMessage '*already exists*Use -Force*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
        $global:dockerCalls | Should -BeNullOrEmpty
    }

    It 'rejects a filesystem root as the destination' {
        $rootPath = [System.IO.Path]::GetPathRoot($TestDrive)
        function global:docker { throw 'Docker should not be called.' }

        { Install-ContainerModule 'example/tool:1.0' -Destination $rootPath -Force } |
            Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage '*destination cannot be a filesystem root*'
    }

    It 'preserves an existing destination when staged manifest validation fails' {
        $destination = Join-Path $TestDrive 'preserved-install'
        New-Item -Path $destination -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'preserve'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'create') { 'container-invalid-module' }
        }

        { Install-ContainerModule 'example/tool:1.0' -Destination $destination -Force } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*exactly one module manifest*Found 0*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
        $global:dockerCalls[-1] | Should -Be 'rm --force container-invalid-module'
        @(Get-ChildItem -LiteralPath $TestDrive -Directory -Filter '.preserved-install.install-*').Count | Should -Be 0
    }

    It 'replaces a validated existing destination with Force' {
        $destination = Join-Path $TestDrive 'replaced-install'
        New-Item -Path $destination -ItemType Directory | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'old.txt') -Value 'old'
        function global:docker {
            $global:dockerCalls.Add(($args -join ' '))
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'create') { 'container-replacement' }
            if ($args[0] -eq 'cp') { Write-TestContainerModule -Path $args[2] }
        }

        Install-ContainerModule 'example/tool:1.0' -Destination $destination -Force | Out-Null

        Test-Path -LiteralPath (Join-Path $destination 'old.txt') | Should -BeFalse
        Test-ModuleManifest -Path (Join-Path $destination 'Example.psd1') -ErrorAction Stop |
            Should -Not -BeNullOrEmpty
    }

    It 'reports when Docker is unavailable' {
        $destination = Join-Path $TestDrive 'missing-docker-install'
        Remove-Item Function:\docker -Force -ErrorAction SilentlyContinue
        $originalPath = $env:PATH
        try {
            $env:PATH = ''
            { Install-ContainerModule 'example/tool:1.0' -Destination $destination } |
                Should -Throw -ExceptionType ([System.InvalidOperationException]) -ExpectedMessage '*Docker is required*not found on PATH*'
        }
        finally {
            $env:PATH = $originalPath
        }
    }
}

Describe 'Test-LocalRepository script' {
    BeforeAll {
        $repositoryPath = Join-Path $TestDrive 'Repository'
        $specificationDirectory = Join-Path $repositoryPath 'PSModule'
        New-Item -Path $specificationDirectory -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $specificationDirectory 'PSModule.psd1') -Value @'
@{ Commands = @(@{ Name = 'Invoke-ExternalRepository'; Parameters = @() }) }
'@
        $scriptPath = Join-Path $PSScriptRoot '..' 'build' 'Test-LocalRepository.ps1'
    }

    It 'returns the target repository model and restores the caller location' {
        $originalLocation = Get-Location

        $model = & $scriptPath -Repository $repositoryPath

        $model.Commands[0].Name | Should -Be 'Invoke-ExternalRepository'
        (Get-Location).Path | Should -Be $originalLocation.Path
    }

    It 'generates repository metadata and restores the caller location' {
        $originalLocation = Get-Location

        $artifact = & $scriptPath -Repository $repositoryPath -Generate -Output './generated'

        $artifact.FullName | Should -Be (Join-Path $repositoryPath 'generated' 'Metadata' 'model.json')
        (Get-Location).Path | Should -Be $originalLocation.Path
    }
}
