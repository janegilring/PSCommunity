<#
.Synopsis
	This script will mirror the OU structure from the specified root OU to a top level folder in the specified Royal TS document and create Remote Desktop Connection objects for all AD computer accounts meeting specific criterias.

.Description
	This script will mirror the OU structure from the specified root OU to a top level folder in the specified Royal TS document and create Remote Desktop Connection objects for all AD computer accounts meeting specific criterias.

    The criterias is the following:
    -The computer object is registered with a Server operating system (the object's "Operatingsystem" LDAP property meets the filter "Windows Server*")
    -The computer object is not a Cluster Name Object (the object's "ServicePrincipalName" LDAP property does not contain the word MSClusterVirtualServer)
    -The computer account has logged on to the domain in the past X number of days (X is 60 days if the parameter InactiveComputerObjectThresholdInDays is not specified)
    
    The purpose of this script is to show how the Royal TS PowerShell module available in Royal TS V3 beta can be used to manage a Royal TS document. Thus it must be customized to meet specific needs, the script shows how to configure a couple of Remote Desktop connection properties as an example.
    The script is meant to be scheduled, for example by using PowerShell Jobs or Scheduled Tasks, in order to have an updated Royal TS document based on active computer accounts in one or more specified Active Directory OU(s).
    For smaller environments it may be appropriate to specify the domain DN as the root OU, but this is not recommended for larger environments. Instead the script may be run multiple times with different OU`s specified as the root OU.

.Parameter RootOUPath
	Specifies the path to the root OU for the OU structure you want to mirror
	Example: 'OU=Servers,DC=lab,DC=local'

.Parameter RoyalDocumentPath
	Specifies the path to the Royal TS document you want to mirror the OU struture in. If the document does not exist, it will be created.
	Example: 'C:\temp\Servers.rtsz'

.Parameter RemoveInactiveComputerObjects
	Switch parameter to specify whether you want to remove inactive computer objects from the Royal TS document

.Parameter InactiveComputerObjectThresholdInDays
	Specifies the number of days for the threshold defining inactive computer objects. If not specified a default value of 60 days will be used.

.Parameter UpdateRoyalComputerProperties
	Switch parameter to specify whether you want to update the Remote Desktop connection properties. Applies for computer objects both new and already present in the Royal TS document.
    	The properties to be updated is hard coded to enable Smart sizing and inheritance of credentials from the parent folder.

.Parameter UpdateRoyalFolderProperties
	Switch parameter to specify whether you want to update the Royal Folder properties. Applies for folder objects both new and already present in the Royal TS document.
    	The properties to be updated is hard coded to enable inheritance of credentials from the parent folder.

.Parameter RTSPSModulePath
	Specifies the path to the Royal TS PowerShell module. If Royal TS V3 beta was installed using the MSI-file, this parameter is not required.
  	Specify the path if you downloaded and extracted the zip-file version of Royal TS V3 to an alternate location.

.Parameter ADCredential
	Specifies the credential to use when communicating with AD Domain Controllers


.Notes
            Name: Update-RoyalFolder.ps1
            Author: Jan Egil Ring
            Date Created: 01 Jan 2015
	        Last Modified: 02 March 2015, Jan Egil Ring

.Example
	& C:\MyScripts\Update-RoyalFolder.ps1 -RootOUPath 'OU=Servers,DC=lab,DC=local' -RoyalDocumentPath C:\temp\Servers.rtsz
	
	Mirrors the OU structure in the C:\temp\Servers.rtsz Royal TS document based on computer accounts from the root OU OU=Servers,DC=lab,DC=local

.Example
	& C:\MyScripts\Update-RoyalFolder.ps1 -RootOUPath 'OU=Servers,DC=lab,DC=local' -RoyalDocumentPath C:\temp\Servers.rtsz -RemoveInactiveComputerObjects -UpdateRoyalComputerProperties -InactiveComputerObjectThresholdInDays 30
	
	Mirrors the OU structure in the C:\temp\Servers.rtsz Royal TS document based on computer accounts from the root OU OU=Servers,DC=lab,DC=local
    Removes computer accounts already present in the Royal TS document folder which have not logged on to the domain for the last 10 days.
    Enables Smart sizing and inheritance of credentials from the parent folder for existing objects if not already enabled.


#>

#requires -Version 4.0 -Module ActiveDirectory

[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$RootOUPath,
        [string]$ADDomainController,
		[string]$RoyalDocumentPath = (Join-Path -Path $env:USERPROFILE -ChildPath ('Documents\' + $env:USERDOMAIN + '.rtsz')),
		[switch]$RemoveInactiveComputerObjects,
      	[string]$InactiveComputerObjectThresholdInDays = '60',
		[switch]$UpdateRoyalComputerProperties,
		[switch]$UpdateRoyalFolderProperties,
       	[string]$RTSPSModulePath = (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'code4ward.net\Royal TS V3\RoyalDocument.PowerShell.dll'),
        [pscredential]$ADCredential
	)


# Verify that the Royal TS PowerShell module is present at the specified path.
# In the beta version of Royal TS V3, the module is not available in $env:PSModulePath and thus needs to be imported explicitly
if (-not (Test-Path -Path $RTSPSModulePath)) {

throw "Royal TS PowerShell module does not exist at $RTSPSModulePath"

}

# Import the Royal TS PowerShell module
if (-not (Get-Module -Name RoyalDocument.PowerShell)) {

Import-Module $RTSPSModulePath

}

if (-not $ADDomainController) {

$ADDomainController = $env:USERDNSDOMAIN

}

# Adding -Credential to AD-cmdlets (if specified)

if ($ADCredential) {

$PSDefaultParameterValues.Add("*-AD*:Credential",$ADCredential)

}

# Create a new RoyalStore in memory
$Store = New-RoyalStore -UserName ($env:USERDOMAIN + '\' + $env:USERNAME)

# Create the new document if it does not exist
if (-not (Test-Path -Path $RoyalDocumentPath)) {

$RoyalDocument = New-RoyalDocument -Name $env:USERDOMAIN -FileName $RoyalDocumentPath -Store $Store

# Store the new document to disk and close it
Out-RoyalDocument -Document $RoyalDocument
Close-RoyalDocument -Document $RoyalDocument

}

# Open the Royal TS document
$RoyalDocument = Open-RoyalDocument -FileName $RoyalDocumentPath -Store $Store

# Define helper functions
function Update-RoyalFolder ($SearchBase, $FolderName)
{
    
$Date = Get-Date



$ADObjects = Get-ADComputer -Server $ADDomainController -searchbase $SearchBase -SearchScope OneLevel -LDAPFilter "(&(objectCategory=computer)(operatingSystem=Windows Server*)(!serviceprincipalname=*MSClusterVirtualServer*))" -Properties description,lastlogondate | 
Where-Object lastlogondate -gt $Date.AddDays(-$InactiveComputerObjectThresholdInDays) |  
Select-Object -Property name,dnshostname,lastlogondate,description |
Sort-Object -Property name



$RoyalFolder = Get-RoyalObject -Type RoyalFolder -Store $Store | Where-Object {$_.Name -eq $FolderName -and $_.Description -eq $SearchBase}

$RDSConnections = Get-RoyalObject -Type RoyalRDSConnection -Store $Store | 
Where-Object {$_.ParentId -eq $RoyalFolder.Id.Guid} 

$RDSConnectionNames = $RDSConnections | Select-Object -ExpandProperty name


if ($ADObjects) {

Write-Verbose -Message "Updating $($FolderName)"

foreach ($ADObject in $ADObjects) 
{

if ($ADObject.Name -notin $RDSConnectionNames) {

    $RDS = New-RoyalObject -Folder $RoyalFolder -Type RoyalRDSConnection -Name $ADObject.Name -Description $ADObject.Description
    $null = Set-RoyalObjectValue -Object $RDS -Property "URI" -Value $ADObject.DnsHostName

    Write-Verbose -Message "Added $($ADObject.Name)"

if ($UpdateRoyalComputerProperties) {
   
   Update-RoyalComputerProperty -ComputerObject $RDS
   
   }
   

    } else {
    
    if ($UpdateRoyalComputerProperties) {

    Update-RoyalComputerProperty
    
    
    }
    
    
    }

}

} else {

Write-Verbose -Message "No computer objects matching the selected filter found in OU $($FolderName)"

}


if ($RDSConnections -and $RemoveInactiveComputerObjects) {

Write-Verbose -Message "Checking OU $($FolderName) for inactive computer objects"

foreach ($item in $RDSConnections) {

        if ($item.Name -notin $ADObjects.Name) {

    Write-Verbose -Message "Removing inactive computer object $($item.Name)"

    $null = Remove-RoyalObject -Object $item

    }
}

}

}


function Test-RoyalFolder ($Description, $FolderName, $ParentFolderName, $ParentFolderNameDescription)
{

$RoyalFolder = Get-RoyalObject -Type RoyalFolder -Store $Store | Where-Object {$_.Name -eq $FolderName -and $_.Description -eq $Description}


if (-not ($RoyalFolder)) {

if ($ParentFolderName) {

$RoyalFolderParent = Get-RoyalObject -Type RoyalFolder -Store $Store | Where-Object {$_.Name -eq $ParentFolderName -and $_.Description -eq $ParentFolderNameDescription}

if (-not ($RoyalFolderParent)) {

throw "Parent does not exists"

}

$RoyalFolder = New-RoyalObject -Folder $RoyalFolderParent -Type RoyalFolder -Name $FolderName -Description $Description

} else {

$RoyalFolder = New-RoyalObject -Folder $RoyalDocument -Type RoyalFolder -Name $FolderName -Description $Description

}

}

    if ($UpdateRoyalFolderProperties) {

    if ($RoyalFolder.CredentialFromParent -ne $true) {

    Write-Verbose -Message "Enabling CredentialFromParent for folder $FolderName"

    $RoyalFolder.CredentialFromParent = $true

    }

    }

}


function Update-RoyalComputerProperty {

param (
$ComputerObject
)

if ($ComputerObject) {

$item = $ComputerObject

} else {

$item = $RDSConnections  | 
where-object {$_.ParentId -eq $RoyalFolder.Id.Guid -and $_.Name -eq $ADObject.Name}

}

Write-Verbose -Message "Checking for computer object $($item.Name) for property compliance"

    if ($item.SmartSizing -ne $true) {

    Write-Verbose -Message "Enabling SmartSizing for computer object $($item.Name)"

    $item.Smartsizing = $true

    }

    if ($item.CredentialFromParent -ne $true) {

    Write-Verbose -Message "Enabling CredentialFromParent for computer object $($item.Name)"

    $item.CredentialFromParent = $true

    }



}


try
{
    $RootOU = Get-ADOrganizationalUnit -Server $ADDomainController -Identity $RootOUPath -ErrorAction Stop
}
catch
{

    $error[0].Exception
    throw "An error occured while retrieving the root OU"
    
    
}


Test-RoyalFolder -FolderName $RootOU.Name -Description $RootOU.DistinguishedName

Update-RoyalFolder -SearchBase $RootOU.DistinguishedName -FolderName $RootOU.Name

$OUs = Get-ADOrganizationalUnit -Server $ADDomainController -SearchBase $RootOU -Filter * -SearchScope OneLevel | Select-Object Name,DistinguishedName


if ($OUs) {

foreach ($OU in $OUs) {

$ParentOU = $RootOU

Test-RoyalFolder -FolderName $OU.Name -Description $OU.DistinguishedName -ParentFolderName $ParentOU.Name -ParentFolderNameDescription $ParentOU.DistinguishedName

Update-RoyalFolder -SearchBase $OU.DistinguishedName -FolderName $OU.Name

$ChildOUs = Get-ADOrganizationalUnit -Server $ADDomainController -SearchBase $OU.DistinguishedName -Filter * -SearchScope OneLevel | Select-Object Name,DistinguishedName

$ChildOUsToProcess = $true

while ($ChildOUsToProcess)
{

$ChildOUsToProcess = @()

foreach ($ChildOU in $ChildOUs) {

$ParentOU = $OU

Test-RoyalFolder -FolderName $ChildOU.Name -Description $ChildOU.DistinguishedName -ParentFolderName $ParentOU.Name -ParentFolderNameDescription $ParentOU.DistinguishedName

Update-RoyalFolder -SearchBase $ChildOU.DistinguishedName -FolderName $ChildOU.Name

$ChildOUsToProcess += Get-ADOrganizationalUnit -Server $ADDomainController -SearchBase $ChildOU.DistinguishedName -Filter * -SearchScope OneLevel | Select-Object Name,DistinguishedName

} #end foreach $ChildOU

$ChildOUs = $ChildOUsToProcess


    
} #end while

} #end foreach $OU

} #end if $OUs
    
# Store the updated document to disk and close it
Out-RoyalDocument -Document $RoyalDocument
Close-RoyalDocument -Document $RoyalDocument