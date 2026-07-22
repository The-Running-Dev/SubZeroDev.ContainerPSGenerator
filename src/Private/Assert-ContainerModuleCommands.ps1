function Assert-ContainerModuleCommands {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) {
        return
    }

    $commands = $Specification['Commands']
    if ($commands -isnot [System.Array]) {
        throw [System.IO.InvalidDataException]::new(
            "The 'Commands' property must be an array."
        )
    }

    $commandNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    for ($index = 0; $index -lt $commands.Count; $index++) {
        $command = $commands[$index]
        if ($command -isnot [System.Collections.IDictionary]) {
            throw [System.IO.InvalidDataException]::new(
                "Command at index $index must be an object."
            )
        }

        $name = $command['Name']
        if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name)) {
            throw [System.IO.InvalidDataException]::new(
                "Command at index $index must define a non-empty string 'Name'."
            )
        }

        if (-not $commandNames.Add($name)) {
            throw [System.IO.InvalidDataException]::new(
                "Command name '$name' is defined more than once. Command names are case-insensitive."
            )
        }
    }
}
