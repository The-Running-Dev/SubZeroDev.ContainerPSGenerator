BeforeAll {
    $manifestPath = Join-Path $PSScriptRoot '..' 'src' 'SubZeroDev.ContainerPSGenerator' 'SubZeroDev.ContainerPSGenerator.psd1'
    Import-Module $manifestPath -Force
}

Describe 'SubZeroDev.ContainerPSGenerator module' {
    It 'has a valid module manifest' {
        Test-ModuleManifest $manifestPath -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'exports Build-ContainerModule' {
        Get-Command Build-ContainerModule -Module SubZeroDev.ContainerPSGenerator |
            Should -Not -BeNullOrEmpty
    }

    It 'declares the specification and output parameters' {
        $command = Get-Command Build-ContainerModule -Module SubZeroDev.ContainerPSGenerator

        $command.Parameters.Specification.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
        $command.Parameters.Output.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
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
