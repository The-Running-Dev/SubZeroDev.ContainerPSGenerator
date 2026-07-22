Set-StrictMode -Version 3.0

$publicFunctions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1'

foreach ($function in $publicFunctions) {
    . $function.FullName
}

Export-ModuleMember -Function $publicFunctions.BaseName
