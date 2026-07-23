Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$messageIndex = [Array]::IndexOf([object[]] $args, '--message')
$message = if ($messageIndex -ge 0 -and $messageIndex + 1 -lt $args.Count) {
    $args[$messageIndex + 1]
}
else {
    $null
}
$readmePath = '/repository/README.md'

[ordered] @{
    Message            = $message
    EnvironmentMessage = $env:EXAMPLE_MESSAGE
    MountedReadme      = Test-Path -LiteralPath $readmePath -PathType Leaf
} | ConvertTo-Json -Compress
