function Get-ServerFromAD {
    <#
      .SYNOPSIS
      Get-ServerFromAD is a command to retrieve server information from Active Directory.
      .DESCRIPTION
      Get-ServerFromAD is a command to retrieve server information from Active Directory.

           Required version: Windows PowerShell 3.0 or later 
           Required modules: ActiveDirectory
           Required privileges: Read-permission in AD

      .EXAMPLE
      Get-ServerFromAD
      .EXAMPLE
      Export data to Excel (requires the ImportExcel module)
      $XlsxPath = 'C:\temp\Servers_AD_InventoryReport.xlsx'
      Get-ServerFromAD | 
      Export-Excel -Path $XlsxPath -WorkSheetname Servers -AutoSize -TableName Servers -TableStyle Light1
  #>

    [CmdletBinding()]
    Param(
        [string]$InactiveComputerObjectThresholdInDays = 60,
        [string]$RootOUPath,
        [string]$ADDomainController,
        [pscredential]$ADCredential
    )

    try {
        
        Import-Module -Name ActiveDirectory -ErrorAction Stop
        
    } catch {
        
        Write-Error -Message 'Prerequisites missing (ActiveDirectory module not installed)'
        break
        
    }

    $Parameters = @{}

    $Parameters.Add('LDAPFilter', "(&(objectCategory=computer)(operatingSystem=Windows Server*)(!serviceprincipalname=*MSClusterVirtualServer*))")

    $ADProperty = 'name', 'operatingSystem', 'lastlogondate', 'description', 'DistinguishedName', 'CanonicalName'
    $Parameters.Add('Properties', $ADProperty)

    if ($ADCredential) {

        $Parameters.Add('Credential', $ADCredential)

    }

    if ($RootOUPath) {

        $Parameters.Add('SearchBase', $RootOUPath)

    }

    if ($ADDomainController) {

        $Parameters.Add('Server', $ADDomainController)

    }

    Get-ADComputer @Parameters |
        Where-Object lastlogondate -gt (Get-Date).AddDays( - $InactiveComputerObjectThresholdInDays) |  
        Select-Object -Property $ADProperty |
        Sort-Object -Property name
        
}