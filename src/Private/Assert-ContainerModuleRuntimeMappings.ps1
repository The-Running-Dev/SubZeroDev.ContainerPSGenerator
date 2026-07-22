function Assert-ContainerModuleRuntimeMappings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Specification
    )

    if (-not $Specification.Contains('Commands')) { return }

    foreach ($command in $Specification['Commands']) {
        if (-not $command.Contains('Parameters')) { continue }
        $workingDirectoryCount = 0
        foreach ($parameter in $command['Parameters']) {
            if (-not $parameter.Contains('Mappings')) { continue }
            foreach ($mapping in $parameter['Mappings']) {
                switch ($mapping['Type']) {
                    'WorkingDirectory' {
                        $workingDirectoryCount++
                        if ($parameter['Type'] -ne 'string') {
                            throw [System.IO.InvalidDataException]::new(
                                "WorkingDirectory mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use type 'string'."
                            )
                        }
                    }
                    'Port' {
                        if ($parameter['Type'] -notin @('int', 'long', 'System.Int32', 'System.Int64')) {
                            throw [System.IO.InvalidDataException]::new(
                                "Port mapping parameter '$($parameter['Name'])' on command '$($command['Name'])' must use an integer type."
                            )
                        }
                        $containerPort = $mapping['ContainerPort']
                        if ($containerPort -isnot [int] -or $containerPort -lt 1 -or $containerPort -gt 65535) {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'ContainerPort' property for Port mapping on parameter '$($parameter['Name'])' must be an integer from 1 through 65535."
                            )
                        }
                        if ($mapping.Contains('Protocol') -and $mapping['Protocol'] -notin @('tcp', 'udp')) {
                            throw [System.IO.InvalidDataException]::new(
                                "The 'Protocol' property for Port mapping on parameter '$($parameter['Name'])' must be 'tcp' or 'udp'."
                            )
                        }
                    }
                }
            }
        }
        if ($workingDirectoryCount -gt 1) {
            throw [System.IO.InvalidDataException]::new(
                "Command '$($command['Name'])' may define at most one WorkingDirectory mapping."
            )
        }
    }
}
