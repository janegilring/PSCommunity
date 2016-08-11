# Toggle regions: Ctrl + M

#region Demo setup
Write-Warning 'This is a demo script which should be run line by line or sections at a time, stopping script execution'

break

<#

    Author:      Jan Egil Ring
    Name:        Azure Automation DSC - bootstrap config.ps1
    Description: This demo script is part of the video presentation 
                 Automatically Configure Your Machines Using Azure Automation DSC at Initial Boot-up
                 
#>

#region Prerequisites

if (-not (Get-Module -Name AzureRM.Automation -ListAvailable)) {

Install-Module -Name AzureRM

}

$AzureCreds = Get-Credential -UserName adminjer@janegilpowershell.onmicrosoft.com -Message .

$PSDefaultParameterValues = @{
  "*AzureRmAutomation*:ResourceGroupName" = 'Automation'
  "*AzureRmAutomation*:AutomationAccountName" = 'Automation-West-Europe'
}

Add-AzureRmAccount -Credential $AzureCreds

#endregion

#region Import DSC configuration to Azure Automation DSC

# https://azure.microsoft.com/en-us/documentation/articles/automation-dsc-compile/
$SourcePath = 'C:\DSC\DemoServersWMF5.ps1'
psedit $SourcePath

Import-AzureRmAutomationDscConfiguration -SourcePath $SourcePath -Force -Published

#endregion

#region Compile MOF-files in Azure Automation

 $ConfigData = @{

    AllNodes = @(
        @{
            NodeName = 'VM1'
            Role = 'WebServer'
        },
        @{
            NodeName = 'VM2'
            Role = "SQLServer"
        },
        @{
            NodeName = 'VM3'
            Role = "FileServer"

        }

    )

} 

Start-AzureRmAutomationDscCompilationJob -ConfigurationName DemoServersWMF5 -ConfigurationData $ConfigData 

#endregion

#region Generate DSC meta-configuration for bootstrapping new virtual machines to Azure Automation

# https://azure.microsoft.com/en-us/documentation/articles/automation-dsc-onboarding/


Get-AzureRmAutomationDscOnboardingMetaconfig -ComputerName VM3 -OutputFolder $env:temp -Force
Get-ChildItem $env:temp\DscMetaConfigs

$DSCMetaConfiguration = Join-Path -Path $env:temp\DscMetaConfigs -ChildPath VM3.meta.mof
psedit $DSCMetaConfiguration


psedit C:\DSC\AzureAutomationDscMetaConfiguration.ps1
. C:\DSC\AzureAutomationDscMetaConfiguration.ps1

$LCMComputerName = 'VM3'
$NodeConfigurationName = 'DemoServersWMF5.VM3'
$RegistrationUrl = 'https://we-agentservice-prod-1.azure-automation.net/accounts/a8072ea5-60ec-4209-b9b0-64c519efbc73'
$RegistrationKey = Get-Content -Path 'C:\DSC\RegistrationKey.txt'
$DSCMOFDirectory = "$env:temp\DscMetaConfigs"

# Create the metaconfigurations
$Params = @{
  RegistrationUrl = $RegistrationUrl
  RegistrationKey = $RegistrationKey
  ComputerName = @($LCMComputerName);
  NodeConfigurationName = $NodeConfigurationName;
  RefreshFrequencyMins = 90;
  ConfigurationModeFrequencyMins = 45;
  RebootNodeIfNeeded = $False;
  AllowModuleOverwrite = $False;
  ConfigurationMode = 'ApplyAndAutoCorrect';
  ActionAfterReboot = 'ContinueConfiguration';
  ReportOnly = $False;  # Set to $True to have machines only report to AA DSC but not pull from it
  OutputPath = $DSCMOFDirectory
}


AzureAutomationDscMetaConfiguration @Params

$DSCMetaConfiguration = Join-Path -Path $env:temp\DscMetaConfigs -ChildPath VM3.meta.mof
psedit $DSCMetaConfiguration

#Optionally (best practice), clear authoring metadata from MOF-file

. C:\DSC\Clear-MofAuthoringMetadata.ps1
psedit C:\DSC\Clear-MofAuthoringMetadata.ps1

Clear-MofAuthoringMetadata -Path $DSCMetaConfiguration
psedit $DSCMetaConfiguration

# $DSCMetaConfiguration should now be ready for use and can be injected into a new VM

#endregion