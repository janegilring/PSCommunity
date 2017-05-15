function Get-HotfixStatus
{
  <#
      .SYNOPSIS
      Get-HotfixStatus is a command to retrieve hotfix information.
      .DESCRIPTION
      Get-HotfixStatus is a command to retrieve hotfix information. This can be used as a tool to identify which servers is missing specific updates.
      .EXAMPLE
      Get information from localhost
      Get-HotfixStatus -HotFixes KB4012212
      .EXAMPLE
      Get hotfix information from a specified computer
      Get-HotfixStatus -ComputerName SRV01 -HotFixes KB4012212
      .EXAMPLE
      Get hotfix status for an array of patches, such as the hotfixes relevant to MS17-010
      $HotFixes = "KB4012212", "KB4012217", "KB4015551", "KB4019216", "KB4012216", "KB4015550", "KB4019215", "KB4013429", "KB4019472", "KB4015217", "KB4015438", "KB4016635"
      Get-HotfixStatus -ComputerName SRV01 -HotFixes $HotFixes
      .EXAMPLE
      Retrieve computers from a given OU Path
      Get-HotfixStatus -Verbose -OUPath 'OU=contoso,DC=tine,DC=com' -HotFixes KB4012212
      .EXAMPLE
      Export the retrieved information to an Excel spreadsheet using the Export-Excel command from the module ImportExcel
      $XlsxPath = 'C:\temp\Servers_HotfixReport.xlsx'
      Get-HotfixStatus -Verbose -OUPath 'OU=contoso,DC=tine,DC=com' | 
      Export-Excel -Path $XlsxPath -WorkSheetname HotfixStatus -AutoSize -TableName HotfixStatus -TableStyle Light1
  #>

  [CmdletBinding()]
  param
  (
    # Hotfixes to report against
    [Parameter(Mandatory=$true)]
    [string[]]
    $HotFixes,

    # OU Path to get computer accounts from
    [Parameter(ParameterSetName='FromActiveDirectory', Mandatory=$false)]
    [string]
    $OUPath,

    # Threshold for filtering inactive computer accounts from Active Directory
    [Parameter(ParameterSetName='FromActiveDirectory', Mandatory=$false)]
    [int]
    $InactiveADComputerObjectThresholdInDays = 60,

    # Credential to be used for connecting to computers using PowerShell Remoting
    [ValidateNotNullOrEmpty()]
    [PSCredential] $Credential,
    
    # Computer name(s) to run the query against
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('__Server','CN')]
    [ValidateNotNullOrEmpty()]
    [string[]] $ComputerName = 'localhost',

    # LDAP Filter to use when querying Active Directory for computer accounts. By default, only accounts with a Windows Server operating system is included. Also, Cluster Name Objects is excluded.
    [Parameter(ParameterSetName='FromActiveDirectory', Mandatory=$false)]
    [string]
    $LDAPFilter = '(&(objectCategory=computer)(operatingSystem=Windows Server*)(!serviceprincipalname=*MSClusterVirtualServer*))'

  )

  begin 
  {

    if ($PsCmdlet.ParameterSetName -eq 'FromActiveDirectory') 
    { 
           
        Write-Verbose -Message "Parameter set: FromActiveDirectory"
      
        $ADComputerParameters = @{}

        Write-Verbose -Message "Using LDAP Filter $LDAPFilter"

        $ADComputerParameters.Add('LDAPFilter',$LDAPFilter)
        $ADComputerParameters.Add('Properties',"lastlogondate")
      
        if ($OUPath) {

          $ADComputerParameters.Add('SearchBase',$OUPath)
  
        }
      
        $Date = Get-Date
        $Computers = Get-ADComputer @ADComputerParameters | 
        Where-Object lastlogondate -gt $Date.AddDays(-$InactiveADComputerObjectThresholdInDays) |  
        Sort-Object -Property name | Select-Object -ExpandProperty name
        
      
      } else {
      
        Write-Verbose -Message "Getting computers from parameter -ComputerName"
      
        $Computers = $ComputerName
      
      }

  }

  process
  {


    foreach ($Computer in $Computers) {

      $PSSessionParameters = @{

         ComputerName = $computer
         ErrorAction = 'Stop'

      }

      if ($PSBoundParameters.ContainsKey('Credential')) {

         $PSSessionParameters.Add('Credential',$Credential)

      }

      try 
      {
        $session = New-PSSession @PSSessionParameters

        $output  = New-Object -TypeName pscustomobject -Property @{
          ComputerName = $session.ComputerName
          Connection   = 'Success'
          ConnectionError = $null
          HotfixInstalled  = $null
        }
      }

      catch 
      {

        Write-Verbose -Message "Failed to connect to $Computer via PowerShell remoting..."

        $output = New-Object -TypeName pscustomobject -Property @{
          ComputerName = $Computer
          Connection   = 'Failed'
          ConnectionError = $_.Exception
          HotfixInstalled  = $null
        }

        if ($session) 
          {
            Remove-Variable -Name session
          }

      }

      if ($session) 
      {
      
      
          Write-Verbose -Message 'Gathering hotfix info...'
      
          $InstalledHotfixes = Invoke-Command -Session $session -ScriptBlock {

            $VerbosePreference = $using:VerbosePreference

            Write-Verbose -Message "Connected to $using:Computer via PowerShell remoting as user $($env:username), gathering hotfix information..."
             
            if (Get-Command -Name Get-Hotfix -ErrorAction SilentlyContinue) {
            
              Get-Hotfix
            
            } elseif (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
            
              # Most likely Nano Server if Get-Hotfix is not present, trying Get-CimInstance instead
              
              Write-Verbose -Message 'Get-HotFix not found, trying Get-CimInstance...'  
              
              Get-CimInstance -ClassName win32_quickfixengineering
            
            } else {
            
              throw 'Neither Get-HotFix nor Get-CimInstance found, unable to check for hotfix'
            
            }
            
            
          
          }

        if ($InstalledHotfixes | Where-Object {$HotFixes -contains $_.HotFixID}) {

          $output.HotfixInstalled = $true

        } else {

          $output.HotfixInstalled = $false

        }  

        Remove-PSSession -Session $session
        
      }

      $output | Select-Object -Property ComputerName, HotfixInstalled, Connection, ConnectionError
 
    }


  }

}