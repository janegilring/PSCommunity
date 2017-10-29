Function Get-MSGraphAzureADUser {

    <#
.SYNOPSIS
This function is used to get AAD Users from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any users registered with AAD
Created based on examples from https://github.com/microsoftgraph/powershell-intune-samples
.EXAMPLE
Get-AADUser
Returns all users registered with Azure AD
.EXAMPLE
Get-AADUser -userPrincipleName user@domain.com
Returns specific user by UserPrincipalName registered with Azure AD
.NOTES
NAME: Get-AADUser
#>

    [cmdletbinding()]

    param
    (
        $UserPrincipalName,
        $AuthToken
    )

    # Defining Variables
    $graphApiVersion = "v1.0"
    $User_resource = "users"

    try {


        $uri = "https://graph.microsoft.com/$graphApiVersion/$($User_resource)/$userPrincipalName"
        Write-Verbose $uri
        Invoke-RestMethod -Uri $uri -Headers $AuthToken -Method Get -ErrorAction Stop


    }

    catch {

        throw  $_.Exception.Message


    }

}