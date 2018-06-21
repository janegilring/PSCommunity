function Install-AvailableWindowsUpdate {
  [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential,      
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName = $Env:COMPUTERNAME,
        [switch]$SelectUpdates
    )
    process {

    foreach ($Computer in $ComputerName) {

          try {
          
            Write-Verbose -Message "Processing computer $Computer"

            $CIMSessionParameters = @{
               SessionOption = (New-CimSessionOption -Protocol Wsman)
               ComputerName = $Computer
               ErrorAction = 'Stop'

            }

            if ($PSBoundParameters.ContainsKey('Credential')) {

               $CIMSessionParameters.Add('Credential',$Credential)

            }


            $CimSession = New-CimSession @CIMSessionParameters

            $CimInstance = New-CimInstance -Namespace root/Microsoft/Windows/WindowsUpdate -ClassName MSFT_WUOperationsSession -CimSession $CimSession -ErrorAction Stop
          
            Write-Verbose -Message "Scanning for updates..."
            
        if ($SelectUpdates) {

              $AvailableUpdates = @($CimInstance | Invoke-CimMethod -MethodName ScanForUpdates -Arguments @{SearchCriteria="IsInstalled=0";OnlineScan=$true} -ErrorAction Stop)

          if ($AvailableUpdates.Updates) {

              [CimInstance[]]$SelectedUpdates =  $AvailableUpdates.Updates | Out-GridView -Title "Select updates to install on computer $Computer" -OutputMode Multiple
              $null = $CimInstance | Invoke-CimMethod -MethodName DownloadUpdates -Arguments @{Updates=$SelectedUpdates} -ErrorAction Stop
              $InstalledUpdates = $CimInstance | Invoke-CimMethod -MethodName InstallUpdates -Arguments @{Updates=$SelectedUpdates} -ErrorAction Stop

          }


        }  else {

            $InstalledUpdates = @($CimInstance | Invoke-CimMethod -MethodName ApplyApplicableUpdates -ErrorAction Stop)
            
          }

            if ($InstalledUpdates) {
            
              Write-Verbose -Message "ApplyApplicableUpdates method ran..."
            
              [pscustomobject]@{
                PSComputerName = $Computer
                Errors = $null
              }  
            
            } else {
            
              Write-Verbose -Message "ApplyApplicableUpdates did not return any status..."
            
              [pscustomobject]@{
                PSComputerName = $Computer
                Errors = $null
              }
            
            
            }
            
            
            
          }
          
          catch {
          
            Write-Verbose -Message "An error occured..."
            
             [pscustomobject]@{
               PSComputerName = $Computer
               Errors = $_.Exception.Message
             }
          
           }
       
        }
    }
}