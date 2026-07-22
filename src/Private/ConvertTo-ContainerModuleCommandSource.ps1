function ConvertTo-ContainerModuleCommandSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Command
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("function $($Command.Name) {")
    $lines.Add('    [CmdletBinding()]')

    if ($Command.Parameters.Count -eq 0) {
        $lines.Add('    param ()')
    }
    else {
        $lines.Add('    param (')
        for ($index = 0; $index -lt $Command.Parameters.Count; $index++) {
            $parameter = $Command.Parameters[$index]
            $mandatory = if ($parameter.Mandatory) { 'Mandatory = $true' } else { '' }
            $separator = if ($index -lt ($Command.Parameters.Count - 1)) { ',' } else { '' }

            $lines.Add("        [Parameter($mandatory)]")
            $lines.Add("        [$($parameter.Type)] `$$($parameter.Name)$separator")
        }
        $lines.Add('    )')
    }

    $lines.Add('')
    $lines.Add("    throw [System.NotImplementedException]::new('Runtime invocation for $($Command.Name) is not implemented yet.')")
    $lines.Add('}')

    return ($lines -join "`n") + "`n"
}
