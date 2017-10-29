
Function Get-MSGraphIntuneUserDevice {

    <#
.SYNOPSIS
This function is used to get an AAD User Devices from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets a users devices registered with Intune MDM
Created based on examples from https://github.com/microsoftgraph/powershell-intune-samples
.EXAMPLE
Get-MSGraphIntuneUserDevice -UserID $UserID
Returns all user devices registered in Intune MDM
.NOTES
NAME: Get-MSGraphIntuneUserDevice
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "UserID (guid) for the user you want to take action on must be specified:")]
        $UserID,
        $AuthenticationToken
    )

    # Defining Variables
    $graphApiVersion = "beta"
    $Resource = "users/$UserID/managedDevices"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Write-Verbose $uri
        (Invoke-RestMethod -Uri $uri -Headers $AuthenticationToken -Method Get -ErrorAction Stop).Value

    }

    catch {

        throw  $_.Exception.Message
 
    }

}