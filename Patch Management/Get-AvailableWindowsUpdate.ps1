function Get-AvailableWindowsUpdate {
  [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [PSCredential] $Credential,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ComputerName = $Env:COMPUTERNAME
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
              
            $AvailableUpdates = @($CimInstance | Invoke-CimMethod -MethodName ScanForUpdates -Arguments @{SearchCriteria="IsInstalled=0";OnlineScan=$true} -ErrorAction Stop)
            
            if ($AvailableUpdates.Updates) {
            
              Write-Verbose -Message "Updates found..."
            
              $AvailableUpdates.Updates | Select-Object -Property PSComputerName,Title,KBArticleID,UpdateID,Description,@{n='Errors';e={$null}}
            
            } else {
            
              Write-Verbose -Message "No updates found..."
            
              [pscustomobject]@{
                PSComputerName = $Computer
                Title = $null
                KBArticleID = $null
                UpdateID = $null
                Description = $null
                Errors = $null
              }
            
            
            }
            
            
            
          }
          
          catch {
          
            Write-Verbose -Message "An error occured..."
          
            [pscustomobject]@{
              PSComputerName = $Computer
              Title = $null
              KBArticleID = $null
              UpdateID = $null
              Description = $null
              Errors = $_.Exception.Message
             }
          
           }
       
        }
    }
}