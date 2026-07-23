FROM mcr.microsoft.com/powershell:7.5-alpine-3.20

COPY Invoke-ExampleContainer.ps1 /app/Invoke-ExampleContainer.ps1
COPY artifacts/PSModule /PSModule

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "/app/Invoke-ExampleContainer.ps1"]
