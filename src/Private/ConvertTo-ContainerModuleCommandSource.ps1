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
    $lines.Add('    <#')
    $lines.Add('    .SYNOPSIS')
    $commandSynopsis = if (-not [string]::IsNullOrWhiteSpace($Command.Synopsis)) {
        $Command.Synopsis
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Command.Description)) {
        $Command.Description
    }
    else {
        "Runs the $($Command.Name) container command."
    }
    foreach ($descriptionLine in $commandSynopsis.Replace('#>', '# >') -split "`r?`n") {
        $lines.Add("    $descriptionLine")
    }
    if (-not [string]::IsNullOrWhiteSpace($Command.Description) -and $Command.Description -ne $commandSynopsis) {
        $lines.Add('')
        $lines.Add('    .DESCRIPTION')
        foreach ($descriptionLine in $Command.Description.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $descriptionLine")
        }
    }
    foreach ($parameter in $Command.Parameters | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Description) }) {
        $lines.Add('')
        $lines.Add("    .PARAMETER $($parameter.Name)")
        foreach ($descriptionLine in $parameter.Description.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $descriptionLine")
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($Command.Notes)) {
        $lines.Add('')
        $lines.Add('    .NOTES')
        foreach ($notesLine in $Command.Notes.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $notesLine")
        }
    }
    foreach ($example in $Command.Examples) {
        $lines.Add('')
        $lines.Add('    .EXAMPLE')
        foreach ($codeLine in $example.Code.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $codeLine")
        }
        $lines.Add('')
        foreach ($descriptionLine in $example.Description.Replace('#>', '# >') -split "`r?`n") {
            $lines.Add("    $descriptionLine")
        }
    }
    $lines.Add('    #>')
    $lines.Add("    [CmdletBinding(SupportsShouldProcess = `$true, ConfirmImpact = 'Low')]")

    if ($Command.Parameters.Count -eq 0) {
        $lines.Add('    param ()')
    }
    else {
        $lines.Add('    param (')
        for ($index = 0; $index -lt $Command.Parameters.Count; $index++) {
            $parameter = $Command.Parameters[$index]
            $mandatory = if ($parameter.Mandatory) { 'Mandatory = $true' } else { '' }
            $separator = if ($index -lt ($Command.Parameters.Count - 1)) { ',' } else { '' }
            $parameterType = switch -Regex ($parameter.Type) {
                '^DirectoryInfo(\[\])?$' { $parameter.Type -replace '^DirectoryInfo', 'System.IO.DirectoryInfo'; break }
                '^FileInfo(\[\])?$' { $parameter.Type -replace '^FileInfo', 'System.IO.FileInfo'; break }
                default { $parameter.Type }
            }

            $lines.Add("        [Parameter($mandatory)]")
            foreach ($validation in $parameter.Validations) {
                switch ($validation.Type) {
                    'ValidateSet' {
                        $values = $validation.Definition['Values'] | ForEach-Object { "'$($_.Replace("'", "''"))'" }
                        $lines.Add("        [ValidateSet($($values -join ', '))]")
                    }
                    'ValidateRange' {
                        $minimum = [System.Convert]::ToString($validation.Definition['Minimum'], [System.Globalization.CultureInfo]::InvariantCulture)
                        $maximum = [System.Convert]::ToString($validation.Definition['Maximum'], [System.Globalization.CultureInfo]::InvariantCulture)
                        $lines.Add("        [ValidateRange($minimum, $maximum)]")
                    }
                    'ValidatePattern' {
                        $pattern = $validation.Definition['Pattern'].Replace("'", "''")
                        $lines.Add("        [ValidatePattern('$pattern')]")
                    }
                }
            }
            $lines.Add("        [$parameterType] `$$($parameter.Name)$separator")
        }
        $lines.Add('    )')
    }

    $lines.Add('')
    $lines.Add('    $dockerArguments = [System.Collections.Generic.List[string]]::new()')
    $lines.Add("    `$dockerArguments.Add('run')")
    $lines.Add("    `$dockerArguments.Add('--rm')")

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Mount') {
            $target = $mapping.Definition['Target'].Replace("'", "''")
            $readOnly = if ($mapping.Definition['Access'] -eq 'ReadOnly') { ',readonly' } else { '' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$dockerArguments.Add('--mount')")
            $lines.Add("        `$dockerArguments.Add('type=bind,source=' + [System.IO.Path]::GetFullPath([string] `$$($parameter.Name)) + ',target=$target$readOnly')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Volume') {
            $target = $mapping.Definition['Target'].Replace("'", "''")
            $readOnly = if ($mapping.Definition['Access'] -eq 'ReadOnly') { ',readonly' } else { '' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if (`$$($parameter.Name) -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*`$') {")
            $lines.Add("            throw [System.ArgumentException]::new('Docker volume name contains unsupported characters.', '$($parameter.Name)')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--mount')")
            $lines.Add("        `$dockerArguments.Add('type=volume,source=' + `$$($parameter.Name) + ',target=$target$readOnly')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Environment') {
            $mappingName = $mapping.Definition['Name'].Replace("'", "''")
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        `$dockerArguments.Add('-e')")
            $lines.Add("        `$dockerArguments.Add('$mappingName=' + [string] `$$($parameter.Name))")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'Port') {
            $containerPort = $mapping.Definition['ContainerPort']
            $protocol = if ($mapping.Definition.Contains('Protocol')) { $mapping.Definition['Protocol'].ToLowerInvariant() } else { 'tcp' }
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if (`$$($parameter.Name) -lt 1 -or `$$($parameter.Name) -gt 65535) {")
            $lines.Add("            throw [System.ArgumentOutOfRangeException]::new('$($parameter.Name)', 'Host port must be from 1 through 65535.')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--publish')")
            $lines.Add("        `$dockerArguments.Add([string] `$$($parameter.Name) + ':$containerPort/$protocol')")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'WorkingDirectory') {
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            $lines.Add("        if ([string]::IsNullOrWhiteSpace(`$$($parameter.Name))) {")
            $lines.Add("            throw [System.ArgumentException]::new('Container working directory cannot be empty.', '$($parameter.Name)')")
            $lines.Add('        }')
            $lines.Add("        `$dockerArguments.Add('--workdir')")
            $lines.Add("        `$dockerArguments.Add(`$$($parameter.Name))")
            $lines.Add('    }')
        }
    }

    foreach ($parameter in $Command.Parameters) {
        foreach ($mapping in $parameter.Mappings | Where-Object Type -eq 'RuntimeOption') {
            $optionName = $mapping.Definition['Name']
            $lines.Add("    if (`$PSBoundParameters.ContainsKey('$($parameter.Name)')) {")
            if ($parameter.Type -eq 'switch') {
                $lines.Add("        `$dockerArguments.Add('$optionName')")
            }
            else {
                $lines.Add("        foreach (`$value in @(`$$($parameter.Name))) {")
                $lines.Add("            `$dockerArguments.Add('$optionName')")
                $lines.Add('            $dockerArguments.Add([string] $value)')
                $lines.Add('        }')
            }
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
    $lines.Add("    if (-not `$PSCmdlet.ShouldProcess('$($ContainerImage.Replace("'", "''"))', 'docker ' + (`$dockerArguments -join ' '))) {")
    $lines.Add('        return')
    $lines.Add('    }')
    $lines.Add('')
    $lines.Add("    if (`$null -eq (Get-Command -Name 'docker' -ErrorAction SilentlyContinue)) {")
    $lines.Add("        throw [System.InvalidOperationException]::new('Docker is required to run this command but was not found on PATH.')")
    $lines.Add('    }')
    $lines.Add('')
    $lines.Add('    $global:LASTEXITCODE = 0')
    $lines.Add('    & docker @dockerArguments')
    $lines.Add('    $dockerSucceeded = $?')
    $lines.Add('    $dockerExitCode = $global:LASTEXITCODE')
    $lines.Add('    if (-not $dockerSucceeded -or $dockerExitCode -ne 0) {')
    $lines.Add('        throw [System.InvalidOperationException]::new("Docker failed with exit code $dockerExitCode.")')
    $lines.Add('    }')
    $lines.Add('}')

    return ($lines -join "`n") + "`n"
}
