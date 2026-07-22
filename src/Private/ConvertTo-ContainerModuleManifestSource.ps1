function ConvertTo-ContainerModuleManifestSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Model
    )

    $functionsToExport = if ($Model.Commands.Count -eq 0) {
        '@()'
    }
    else {
        $entries = $Model.Commands | ForEach-Object { "        '$($_.Name.Replace("'", "''"))'" }
        "@(`n$($entries -join "`n")`n    )"
    }

    @"
@{
    RootModule        = '$($Model.ModuleName).psm1'
    ModuleVersion     = '$($Model.ModuleVersion)'
    FunctionsToExport = $functionsToExport
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
"@.Replace("`r`n", "`n")
}
