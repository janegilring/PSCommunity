[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Justification = "By design - passwords is being generated")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification = "By design - passwords is being generated")]
param (
    $PasswordLength = 12,
    $SpecialCharCount = 2,
    $PasswordAgeThreshold = 180,
    [bool]$Force = $false
)

<#

 NAME: Reset-LocalAdministratorPassword.ps1

 AUTHOR: Jan Egil Ring
 EMAIL: jan.egil.ring@outlook.com

 COMMENT: Runbook to reset the local administrator password on Windows servers (tested on Windows Server 2008 R2 - 2019).

  Logic:
        -4 parameters:  -PasswordLength
                        -SpecialCharCount
                        -PasswordAgeThreshold
                        -Force

        -Retrieve all computer accounts from Active Directory with "Server" present in the operating system property, except domain controllers
        -Connect to Azure Key Vault
        -Foreach Server in Servers
            -Check if existing entry for the server is present in Key Vault
                -If yes
                    -Check when password was last updated
                        If older than specified threshold (default 180 days), update password
                    -Check if Force parameter is true
                        -If yes
                            -Update password
                -If no: Update password

 VERSION HISTORY:
 1.0 29.09.2019 - Initial release

 Changes tracked in source control:
https://github.com/janegilring/PSCommunity/tree/master/Azure/Automation/Runbooks/Reset-LocalAdministratorPassword.ps1

 #>

Write-Output -InputObject "Runbook Reset-LocalAdministratorPassword started $(Get-Date) on Azure Automation Runbook Worker $($env:computername)"

#region Variables

Write-Output 'Getting credentials and variables from Azure Automation assets...'

$ADCredential = Get-AutomationPSCredential -name 'cred-ServerAdmin'
$AzureCredential = Get-AutomationPSCredential -Name cred-Azure
$AzureSubscriptionId = '1234567-e9b5-4648-ab8b-815e2ef18a2b'
$KeyVaultName = 'server-vault'
$KeyVaultResourceGroupName = 'infrastructure-automation-rg'
$InactiveComputerObjectThresholdInDays = 30
$ExclusionsADGroup = 'Azure_Key_Vault_LocalAdministratorPassword_Exclusions'

#endregion

#region Modules

Write-Output 'Importing prerequisite PowerShell modules'

try {

    Import-Module -Name Az.KeyVault -ErrorAction Stop -RequiredVersion 1.3.0
    Import-Module -Name ActiveDirectory -ErrorAction Stop

}

catch {

    Write-Error -Message "Prerequisites not available. Error: $($_.Exception.Message)"

    break
}

#endregion


Write-Output 'Authenticating to Azure...'

try {

    $null = Add-AzAccount -Credential $AzureCredential -ErrorAction Stop
    $null = Set-AzContext -Subscription $AzureSubscriptionId -ErrorAction Stop

}

catch {

    Write-Error "Failed to authenticate to Azure and configure subscription context: $($_.Exception.Message)"

    break

}


$KeyVault = Get-AzKeyVault -VaultName $KeyVaultName -ResourceGroupName $KeyVaultResourceGroupName

if (-not ($KeyVault)) {

    Write-Warning "Key Vault does not exist - aborting"

    break

}

#region Prosessing servers

Write-Output 'Getting active servers from Active Directory'

# Retrieves all computer accounts from the current domain with the operating system property starting with "Windows Server", excluding failover clustering virtual accounts as well as domain controllers (userAccountControl value 8192 = SERVER_TRUST_ACCOUNT = Domain Controller), filtering out those who haven`t logged on for the last specified amount of days.
$ServersFromAD = Get-ADComputer -LDAPFilter "(&(objectCategory=computer)(operatingSystem=Windows Server*)(!serviceprincipalname=*MSClusterVirtualServer*)(!userAccountControl:1.2.840.113556.1.4.803:=8192))" -Properties description, lastlogondate, operatingSystem, DistinguishedName |
Where-Object lastlogondate -gt (Get-Date).AddDays( - $InactiveComputerObjectThresholdInDays)

$ExcludedComputerAccounts = Get-ADGroupMember -Identity $ExclusionsADGroup | Select-Object -ExpandProperty Name

Write-Output "Found $(@($ServersFromAD).Count) server(s)"

foreach ($Server in $ServersFromAD) {

    Write-Output "Processing $($Server.Name)"

    if ($Server.Name -in $ExcludedComputerAccounts) {

        Write-Output "$($Server.Name) is a member of AD group $ExclusionsADGroup - skipping"

    } else {

    $ExistingPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $Server.Name

    if (-not ($ExistingPassword)) {

        Write-Output "Password for this server does not exist in Key Vault - creating"

        $UpdatePassword = $true

    } else {

        $PasswordAge = (New-TimeSpan -Start $ExistingPassword.Updated).Days

        if ($PasswordAge -ge $PasswordAgeThreshold -or $Force) {

            Write-Output "Password age in days: $PasswordAge Threshold: $PasswordAgeThreshold"
            Write-Output "Force password change variable: $Force"
            Write-Output "Updating password"

            $UpdatePassword = $true

        } else {

            Write-Output "Password age in days: $PasswordAge Threshold: $PasswordAgeThreshold"
            Write-Output "Current password status OK"

            $UpdatePassword = $false

        }

    }

if ($UpdatePassword) {

    try {

        Add-Type -AssemblyName System.Web
        $Password = [System.Web.Security.Membership]::GeneratePassword($PasswordLength, $SpecialCharCount)
        $PasswordSecureString = (ConvertTo-SecureString -String $Password -AsPlainText -Force)

        Invoke-Command -ComputerName $Server.Name -Credential $ADCredential -ScriptBlock {

            try {

                $account = [ADSI]("WinNT://$($env:computername)/Administrator,user")
                $account.psbase.invoke("setpassword", $using:Password)

            }

            catch {

                Write-Error "Failed to Change the administrator password. Error: $($_.Exception.Message)"

            }

        } -ErrorAction Stop


        $null = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $Server.Name -SecretValue $PasswordSecureString -ContentType 'Local Administrator password' -ErrorAction Stop

    }

    catch {

        Write-Error "Error occured: $($_.Exception.Message)"

     }

    }

  }

}

#endregion

Write-Output -InputObject "Runbook Reset-LocalAdministratorPassword finished $(Get-Date)"