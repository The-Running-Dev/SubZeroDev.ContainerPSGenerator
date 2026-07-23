[CmdletBinding()]
param ()

$repositoryRoot = Split-Path $PSScriptRoot -Parent

& git -C $repositoryRoot submodule update --init --recursive
if ($LASTEXITCODE -ne 0) {
    throw "Initializing integration repository submodules failed with exit code $LASTEXITCODE."
}

& git -C $repositoryRoot submodule status --recursive
if ($LASTEXITCODE -ne 0) {
    throw "Reading integration repository submodule status failed with exit code $LASTEXITCODE."
}
