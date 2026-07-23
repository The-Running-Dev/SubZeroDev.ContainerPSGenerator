param (
    [Parameter(Mandatory)]
    [psobject] $Context
)

$Context.Model = ConvertTo-ContainerModuleModel -Specification $Context.Specification
$Context.Model | Add-Member -MemberType NoteProperty -Name Inspection -Value $Context.Inspection
