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
        { Build-ContainerModule } |
            Should -Throw -ExceptionType ([System.NotImplementedException]) -ExpectedMessage "*Specification: 'PSModule/PSModule.psd1'; Output: 'artifacts/PSModule'*"
    }

    It 'loads an explicitly selected specification' {
        Set-Content -LiteralPath (Join-Path $TestDrive 'Custom.psd1') -Value '@{ Commands = @() }'

        { Build-ContainerModule -Specification './Custom.psd1' -Output './dist' } |
            Should -Throw -ExceptionType ([System.NotImplementedException]) -ExpectedMessage "*Specification: './Custom.psd1'; Output: './dist'*"
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

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.NotImplementedException])
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
'@

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.IO.InvalidDataException]) -ExpectedMessage '*defined more than once*'
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

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.NotImplementedException])
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

        { Build-ContainerModule -Specification './Specification.psd1' } |
            Should -Throw -ExceptionType ([System.NotImplementedException])
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
}
