BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $generatorManifest = Join-Path $repositoryRoot 'src' 'SubZeroDev.ContainerPSGenerator.psd1'
    $fixtureSource = Join-Path $repositoryRoot 'examples' 'EndToEnd'
    $fixturePath = Join-Path $TestDrive 'EndToEnd'
    $generatedModulePath = Join-Path $fixturePath 'artifacts' 'PSModule'
    $installedModulePath = Join-Path $TestDrive 'Installed' 'ContainerE2E'
    $isAct = $env:ACT -eq 'true'
    $mountedRepositoryPath = if ($isAct) { '/tmp' } else { Join-Path $TestDrive 'Repository' }
    $image = 'subzerodev-containerpsgenerator-e2e:local'

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker is required for the container end-to-end tests.'
    }
    & docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker is not available for the container end-to-end tests.'
    }

    Copy-Item -LiteralPath $fixtureSource -Destination $fixturePath -Recurse
    Import-Module $generatorManifest -Force

    Push-Location $fixturePath
    try {
        $null = Build-ContainerModule -Specification './PSModule/PSModule.psd1' -Output './artifacts/PSModule'
    }
    finally {
        Pop-Location
    }

    & docker build --tag $image $fixturePath
    if ($LASTEXITCODE -ne 0) {
        throw "Building the end-to-end fixture image failed with exit code $LASTEXITCODE."
    }

    $null = Install-ContainerModule $image -Destination $installedModulePath
    Import-Module (Join-Path $installedModulePath 'ContainerE2E.psd1') -Force

    if (-not $isAct) {
        $null = New-Item -Path $mountedRepositoryPath -ItemType Directory -Force
        Set-Content -LiteralPath (Join-Path $mountedRepositoryPath 'sentinel.txt') -Value 'mounted-content' -NoNewline
    }
}

AfterAll {
    Remove-Module ContainerE2E -Force -ErrorAction SilentlyContinue
    Remove-Module SubZeroDev.ContainerPSGenerator -Force -ErrorAction SilentlyContinue
    & docker image rm --force $image 2>&1 | Out-Null
}

Describe 'Container module end-to-end workflow' {
    It 'embeds and installs the generated module from /PSModule' {
        Test-Path -LiteralPath (Join-Path $installedModulePath 'ContainerE2E.psd1') -PathType Leaf |
            Should -BeTrue
        Get-Command Invoke-ContainerE2E -Module ContainerE2E | Should -Not -BeNullOrEmpty
    }

    It 'runs the generated command through Docker with arguments, environment, and a mount' {
        $result = Invoke-ContainerE2E `
            -Message 'hello-from-e2e' `
            -EnvironmentValue 'environment-from-e2e' `
            -Repository (Get-Item -LiteralPath $mountedRepositoryPath) |
            ConvertFrom-Json

        $result.Message | Should -Be 'hello-from-e2e'
        $result.EnvironmentValue | Should -Be 'environment-from-e2e'
        if ($isAct) {
            $result.MountedFileExists | Should -BeFalse
            $result.MountedFileContent | Should -BeNullOrEmpty
        }
        else {
            $result.MountedFileExists | Should -BeTrue
            $result.MountedFileContent | Should -Be 'mounted-content'
        }
    }

    It 'provides generated help and previews without running Docker' {
        (Get-Help Invoke-ContainerE2E).Synopsis | Should -Be 'Runs the end-to-end fixture container.'

        $previewResult = @(
            Invoke-ContainerE2E `
                -Message 'preview' `
                -EnvironmentValue 'preview-environment' `
                -Repository (Get-Item -LiteralPath $mountedRepositoryPath) `
                -WhatIf
        )

        $previewResult.Count | Should -Be 0
    }
}
