function Get-HotfixStatus
{
  <#
      .SYNOPSIS
      Get-HotfixStatus is a command to retrieve hotfix information from servers.
      .DESCRIPTION
      Get-HotfixStatus is a command to retrieve hotfix information from servers. This can be used as a tool to identify which servers is missing specific updates.
      .EXAMPLE
      Henter info fra localhost
      Get-HotfixStatus -HotFixes KB4012212
      .EXAMPLE
      Henter info fra en eller flere servere som angis manuelt
      Get-HotfixStatus -ComputerName SRV01 -HotFixes KB4012212
      .EXAMPLE
      Henter maskinkontoer fra angitt OU i AD
      Get-HotfixStatus -Verbose -OUPath 'OU=Servers,DC=contoso,DC=com' -HotFixes KB4012212
      .EXAMPLE
      $XlsxPath = 'C:\temp\Servers_HotfixReport.xlsx'
      Get-HotfixStatus -Verbose -OUPath 'OU=Servers,DC=contoso,DC=com' | 
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
    [string[]] $ComputerName = 'localhost'
  )

  begin 
  {

    if ($PsCmdlet.ParameterSetName -eq 'FromActiveDirectory') 
    { 
           
        Write-Verbose -Message "Parameter set: FromActiveDirectory"
      
        $ADComputerParameters = @{}

        $ADComputerParameters.Add('LDAPFilter',"(&(objectCategory=computer)(operatingSystem=Windows Server*)(!serviceprincipalname=*MSClusterVirtualServer*))")
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