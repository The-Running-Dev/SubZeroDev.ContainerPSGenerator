Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$messageIndex = [Array]::IndexOf([object[]] $args, '--message')
$message = if ($messageIndex -ge 0 -and $messageIndex + 1 -lt $args.Count) {
    $args[$messageIndex + 1]
}
else {
    $null
}

[ordered] @{
    Message            = $message
    EnvironmentValue   = $env:E2E_VALUE
    MountedFileExists  = Test-Path -LiteralPath '/workspace/sentinel.txt' -PathType Leaf
    MountedFileContent = if (Test-Path -LiteralPath '/workspace/sentinel.txt' -PathType Leaf) {
        Get-Content -LiteralPath '/workspace/sentinel.txt' -Raw
    }
    else {
        $null
    }
} | ConvertTo-Json -Compress
