Function Invoke-MSGraphIntuneDeviceAction {

    <#
      .SYNOPSIS
      This function is used to set a generic intune resources from the Graph API REST interface
      .DESCRIPTION
      The function connects to the Graph API Interface and sets a generic Intune Resource
      Created based on examples from https://github.com/microsoftgraph/powershell-intune-samples
      .EXAMPLE
      Invoke-MSGraphIntuneDeviceAction -DeviceID $DeviceID -remoteLock
      Resets a managed device passcode
      .NOTES
      NAME: Invoke-MSGraphIntuneDeviceAction
  #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Auth header must be specified:")]
        [object]$AuthenticationToken,
        [switch]$RemoteLock,
        [switch]$ResetPasscode,
        [switch]$RemoveCompanyData,
        [switch]$FactoryReset,
        [switch]$Reboot,
        [Parameter(Mandatory = $true, HelpMessage = "DeviceId (guid) for the Device you want to take action on must be specified:")]
        $DeviceID
    )
 

    $graphApiVersion = "Beta"

    try {

        $Count_Params = 0

        if ($RemoteLock.IsPresent) { $Count_Params++ }
        if ($ResetPasscode.IsPresent) { $Count_Params++ }
        if ($RemoveCompanyData.IsPresent) { $Count_Params++ }
        if ($factoryReset.IsPresent) { $Count_Params++ }
        if ($Reboot.IsPresent) { $Count_Params++ }

        if ($Count_Params -eq 0) {

            write-host "No parameter set, specify -RemoteLock -ResetPasscode or -Wipe against the function" -f Red

        }

        elseif ($Count_Params -gt 1) {

            write-host "Multiple parameters set, specify a single parameter -RemoteLock -ResetPasscode or -Wipe against the function" -f Red

        }

        elseif ($RemoteLock) {

            $Resource = "managedDevices/$DeviceID/remoteLock"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending remoteLock command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $AuthenticationToken -Method Post -ErrorAction Stop

        }


        elseif ($Reboot) {

            $Resource = "managedDevices/$DeviceID/rebootNow"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending remoteLock command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $AuthenticationToken -Method Post -ErrorAction Stop

        }

        elseif ($ResetPasscode) {


            $Resource = "managedDevices/$DeviceID/resetPasscode"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending remotePasscode command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $AuthenticationToken -Method Post -ErrorAction Stop


        }

        elseif ($RemoveCompanyData) {

            $Resource = "managedDevices/$DeviceID/retire"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending removeCompanyData command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $AuthenticationToken -Method Post -ErrorAction Stop


        }

        elseif ($factoryReset) {


            $Resource = "managedDevices/$DeviceID/wipe"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            write-verbose $uri
            Write-Verbose "Sending factoryReset command to $DeviceID"
            Invoke-RestMethod -Uri $uri -Headers $AuthenticationToken -Method Post -ErrorAction Stop


        }

    }

    catch {

        throw  $_.Exception.Message

    }

}