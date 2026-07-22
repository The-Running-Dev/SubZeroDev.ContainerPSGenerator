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

    It 'defaults to the conventional specification and output paths' {
        $command = Get-Command Build-ContainerModule -Module SubZeroDev.ContainerPSGenerator

        $command.Parameters.Specification.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty
        $command.Parameters.Output.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }) |
            Should -Not -BeNullOrEmpty

        { Build-ContainerModule } | Should -Throw -ExpectedMessage "*Specification: 'PSModule/PSModule.psd1'; Output: 'artifacts/PSModule'*"
    }
}
