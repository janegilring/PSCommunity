<#

The use of Find/Install-Module requires PowerShell 5.0.
If you are running PowerShell 4.0, which is the minimum version required for authoring DSC configurations and resources), 
you can download the latest version from the xDSCResourceDesigner repository on GitHub:
https://github.com/PowerShell/xDSCResourceDesigner

#>


Find-Module -Name xDSCResourceDesigner | Install-Module -Force

Import-Module xDSCResourceDesigner

Get-Command -Module xDSCResourceDesigner

New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules" -Name PSCommunityDSCResources -ItemType Directory
New-ModuleManifest -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PSCommunityDSCResources\PSCommunityDSCResources.psd1" -Guid (([guid]::NewGuid()).Guid) -Author 'Jan Egil Ring' -CompanyName PSCommunity -ModuleVersion 1.0 -Description 'Example DSC Resource Module for PSCommunity' -PowerShellVersion 4.0 -FunctionsToExport '*.TargetResource'


# Define DSC parameters 
$DataCollectorSetName = New-xDscResourceProperty -Type String -Name DataCollectorSetName -Attribute Key
$Ensure = New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent"
$XmlTemplatePath = New-xDscResourceProperty -Name XmlTemplatePath -Type String -Attribute Required

# Create the DSC resource 
New-xDscResource -Name Logman -Property $DataCollectorSet,$Ensure,$XmlTemplatePath -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PSCommunityDSCResources" -ClassVersion 1.0 -FriendlyName Logman -Force

tree /a /f "$env:ProgramFiles\WindowsPowerShell\Modules\PSCommunityDSCResources"