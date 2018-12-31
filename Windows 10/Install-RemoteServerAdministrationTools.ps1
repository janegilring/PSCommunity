# List all Remote Server Administration Tools (RSAT)
Get-WindowsCapability -Online -Name RSAT*

# Retrieve the state of an RSAT tool
Get-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0

# Install an RSAT tool
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0