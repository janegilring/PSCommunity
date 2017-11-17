# escape=`
# Args used by from statements must be defined here:
ARG NanoServerVersion=1709
ARG WindowsServerCoreVersion=latest
ARG WindowsServerCoreRepo=microsoft/windowsservercore
ARG NanoServerRepo=microsoft/nanoserver

# Use server core as an installer container to extract PowerShell,
# As this is a multi-stage build, this stage will eventually be thrown away
FROM ${WindowsServerCoreRepo}:$WindowsServerCoreVersion AS installer-env

# Arguments for installing powershell, must be defined in the container they are used
ARG PS_VERSION=6.0.0-beta.9

ENV PS_DOWNLOAD_URL https://github.com/PowerShell/PowerShell/releases/download/v$PS_VERSION/PowerShell-$PS_VERSION-win-x64.zip

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN if (!($env:PS_VERSION -match '^\d+\.\d+\.\d+(-\w+\.\d+)?$' )) {throw ('PS_Version ({0}) must match the regex "^\d+\.\d+\.\d+(-\w+\.\d+)?$"' -f $env:PS_VERSION)}
RUN Invoke-WebRequest $Env:PS_DOWNLOAD_URL -OutFile powershell.zip

RUN Expand-Archive powershell.zip -DestinationPath \PowerShell

# Install PowerShell into NanoServer
#FROM ${NanoServerRepo}:$NanoServerVersion
FROM microsoft/aspnetcore:2.0-nanoserver-1709

ARG VCS_REF="none"
ARG PS_VERSION=6.0.0-beta.9
ARG IMAGE_NAME=microsoft/powershell

# Copy Powershell Core from the installer containter
ENV ProgramFiles C:\Program Files
COPY --from=installer-env ["\\PowerShell\\", "$ProgramFiles\\PowerShell"]

# Persist %PSCORE% ENV variable for user convenience
ENV PSCORE="$ProgramFiles\PowerShell\pwsh.exe"

# Set the path
RUN setx PATH "%PATH%;%ProgramFiles%\PowerShell"

SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN pwsh -command mkdir C:\dashboards

RUN pwsh -command Save-Module -Name UniversalDashboard -Path C:\dashboards -Force

RUN pwsh -command $dir = dir C:\dashboards -Directory | Foreach-Object { dir $PSItem.FullName -Directory }; dir $dir.FullName | Copy-Item -Destination C:\dashboards\UniversalDashboard -Recurse

COPY ["dashboard.ps1", "c:/dashboards/dashboard.ps1"]

EXPOSE 80

ENTRYPOINT ["pwsh.exe", "-executionpolicy", "bypass", "-command", "c:/dashboards/dashboard.ps1"]