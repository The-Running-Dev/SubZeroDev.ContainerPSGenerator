function ConvertTo-ContainerModuleCommandSource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Command,

        [Parameter(Mandatory)]
        [string] $ContainerImage
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
    $lines.Add('    $dockerArguments = [System.Collections.Generic.List[string]]::new()')
    $lines.Add("    `$dockerArguments.Add('run')")
    $lines.Add("    `$dockerArguments.Add('--rm')")

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Environment') {
            $mappingName = $mapping.Definition['Name'].Replace("'", "''")
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$dockerArguments.Add('-e')")
            $lines.Add("        `$dockerArguments.Add('$mappingName=' + [string] `$$($parameter.Name))")
            $lines.Add('    }')
        }
    }

    $lines.Add("    `$dockerArguments.Add('$($ContainerImage.Replace("'", "''"))')")

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Argument') {
            $mappingName = $mapping.Definition['Name'].Replace("'", "''")
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            if ($parameter.Type -eq 'switch') {
                $lines.Add("        `$dockerArguments.Add('$mappingName')")
            }
            else {
                $lines.Add("        foreach (`$value in @(`$$($parameter.Name))) {")
                $lines.Add("            `$dockerArguments.Add('$mappingName')")
                $lines.Add('            $dockerArguments.Add([string] $value)')
                $lines.Add('        }')
            }
            $lines.Add('    }')
        }
    }

    $lines.Add('')
    $lines.Add('    & docker @dockerArguments')
    $lines.Add('}')

    return ($lines -join "`n") + "`n"
}
