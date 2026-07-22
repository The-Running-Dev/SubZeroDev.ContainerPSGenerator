FROM mcr.microsoft.com/powershell:7.5-ubuntu-22.04 AS powershell

FROM catthehacker/ubuntu:act-latest

COPY --from=powershell /opt/microsoft/powershell/7 /opt/microsoft/powershell/7
RUN ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
