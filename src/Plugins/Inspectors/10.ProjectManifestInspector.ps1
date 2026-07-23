param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

function Get-FirstXmlValue {
    param (
        [Parameter(Mandatory)] [xml] $Document,
        [Parameter(Mandatory)] [string] $Name
    )

    $node = $Document.SelectSingleNode("//*[local-name()='PropertyGroup']/*[local-name()='$Name']")
    if ($node) { return $node.InnerText.Trim() }
    return $null
}

function Get-SortedPropertyNames {
    param ([psobject] $Object)

    if ($null -eq $Object) { return @() }
    $names = @($Object.PSObject.Properties.Name)
    [Array]::Sort($names, [System.StringComparer]::Ordinal)
    return $names
}

function Get-JsonPropertyValue {
    param (
        [psobject] $Object,
        [string] $Name,
        $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) {
        return $Object.$Name
    }
    return $Default
}

$manifestItems = @(
    Get-ChildItem -LiteralPath $Context.RepositoryPath -Recurse -File |
        Where-Object {
            ($_.Extension -eq '.csproj' -or $_.Name -eq 'package.json') -and
            (Test-ContainerModuleInspectionPath -Context $Context -Path $_.FullName)
        }
)
[Array]::Sort(
    $manifestItems,
    [System.Collections.Generic.Comparer[object]]::Create({
        param ($left, $right)
        [System.StringComparer]::Ordinal.Compare($left.FullName, $right.FullName)
    })
)

$dotNetProjects = [System.Collections.Generic.List[object]]::new()
$nodeProjects = [System.Collections.Generic.List[object]]::new()

foreach ($manifestItem in $manifestItems) {
    $relativePath = [System.IO.Path]::GetRelativePath($Context.RepositoryPath, $manifestItem.FullName).Replace('\', '/')

    if ($manifestItem.Extension -eq '.csproj') {
        [xml] $document = Get-Content -LiteralPath $manifestItem.FullName -Raw
        $targetFrameworks = Get-FirstXmlValue -Document $document -Name 'TargetFrameworks'
        if (-not $targetFrameworks) {
            $targetFrameworks = Get-FirstXmlValue -Document $document -Name 'TargetFramework'
        }

        $packageReferences = @(
            foreach ($reference in $document.SelectNodes("//*[local-name()='PackageReference']")) {
                $versionNode = $reference.SelectSingleNode("./*[local-name()='Version']")
                [ordered] @{
                    Name    = $reference.GetAttribute('Include')
                    Version = if ($reference.GetAttribute('Version')) {
                        $reference.GetAttribute('Version')
                    }
                    elseif ($versionNode) {
                        $versionNode.InnerText.Trim()
                    }
                    else {
                        $null
                    }
                }
            }
        )

        $dotNetProjects.Add([ordered] @{
            Path              = $relativePath
            Sdk               = $document.DocumentElement.GetAttribute('Sdk')
            TargetFrameworks  = @($targetFrameworks -split ';' | Where-Object { $_ } | ForEach-Object { $_.Trim() })
            OutputType        = Get-FirstXmlValue -Document $document -Name 'OutputType'
            AssemblyName      = Get-FirstXmlValue -Document $document -Name 'AssemblyName'
            PackageId         = Get-FirstXmlValue -Document $document -Name 'PackageId'
            PackageReferences = $packageReferences
        })
        continue
    }

    $package = Get-Content -LiteralPath $manifestItem.FullName -Raw | ConvertFrom-Json
    $privateValue = Get-JsonPropertyValue -Object $package -Name 'private' -Default $false
    $nodeProjects.Add([ordered] @{
        Path            = $relativePath
        Name            = Get-JsonPropertyValue -Object $package -Name 'name'
        Version         = Get-JsonPropertyValue -Object $package -Name 'version'
        Private         = [bool] $privateValue
        PackageManager  = Get-JsonPropertyValue -Object $package -Name 'packageManager'
        Scripts         = @(Get-SortedPropertyNames (Get-JsonPropertyValue -Object $package -Name 'scripts'))
        Dependencies    = @(Get-SortedPropertyNames (Get-JsonPropertyValue -Object $package -Name 'dependencies'))
        DevDependencies = @(Get-SortedPropertyNames (Get-JsonPropertyValue -Object $package -Name 'devDependencies'))
    })
}

$Context.Inspection['DotNetProjects'] = @($dotNetProjects)
$Context.Inspection['NodeProjects'] = @($nodeProjects)
