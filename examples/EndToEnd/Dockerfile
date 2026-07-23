FROM mcr.microsoft.com/powershell:7.5-alpine-3.20

COPY Invoke-Fixture.ps1 /app/Invoke-Fixture.ps1
COPY artifacts/PSModule /PSModule

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "/app/Invoke-Fixture.ps1"]
