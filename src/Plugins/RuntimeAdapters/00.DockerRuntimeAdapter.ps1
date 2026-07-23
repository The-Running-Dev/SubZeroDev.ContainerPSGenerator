param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

if ($null -eq $Context.Model) {
    throw [System.InvalidOperationException]::new(
        'The Docker runtime adapter requires a container module model.'
    )
}

foreach ($command in $Context.Model.Commands) {
    $sourceKind = if ($command.Definition.ContainsKey('SourceKind')) {
        [string] $command.Definition['SourceKind']
    }
    else {
        $null
    }

    if ($sourceKind -notin @('Script', 'ModuleFunction')) {
        $command | Add-Member -MemberType NoteProperty -Name RuntimeAdapter -Value 'Docker' -Force
    }
}
