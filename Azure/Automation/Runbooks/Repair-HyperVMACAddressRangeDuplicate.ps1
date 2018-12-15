<#

 NAME: Repair-HyperVMACAddressRangeDuplicate.ps1

 AUTHOR: Jan Egil Ring 
 EMAIL: jan.egil.ring@outlook.com 

 COMMENT: Runbook to test for MAC address duplicates on Hyper-V hosts.
          
    Hyper-V generates the MAC address as described below (mapping MAC address to aa-bb-cc-dd-ee-ff):
    -The first three octets (aa-bb-cc) are Microsoft's IEEE organizationally Unique Identifier, 00:15:5D (which is common on all Hyper-V hosts.
    -The next two octets (dd-ee) are derived from the last two octets of the server's IP address.
    -The last octet (ff) is automatically generated from the range 0x0-0xFF.

    Source: https://support.microsoft.com/en-us/help/2804678/windows-hyper-v-server-has-a-default-limit-of-256-dynamic-mac-addresse


 Logic:
    -Get all Hyper-V hosts from VMM
    -Check for duplicate MAC address ranges
    -Foreach server in hosts with duplicates
        -Generate new octets (7th and 8th)
        -Configure new MAC address ranges on the hosts 
    -If duplicates found, send mail notification

 VERSION HISTORY: 
 1.0 14.12.2018 - Initial release 

 #>

Write-Output -InputObject "Runbook Repair-HyperVMACAddressRangeDuplicate started $(Get-Date) on Azure Automation Runbook Worker $($env:computername)"


#region Variables

Write-Output -InputObject 'Getting variables from Azure Automation assets...'

$VMMCredential = Get-AutomationPSCredential -name 'VMM'
$NodeCredential = Get-AutomationPSCredential -name 'Hyper-V node credentials'
$VMMServer = Get-AutomationVariable -name 'VMMServer'
$SMTPServer = Get-AutomationVariable -name 'SMTPServer'
$MailNotificationRecipients = Get-AutomationVariable -name 'HyperVNotificationRecipients'

#endregion

Write-Output -InputObject 'Getting Hyper-V host computer names from Virtual Machine Manager...'

$VMHosts = Invoke-Command -ComputerName $VMMServer -Credential $VMMCredential -ScriptBlock {

    $null = Get-SCVMMServer -ComputerName $using:VMMServer

    Get-SCVMHost | Where-Object {$PSItem.CommunicationStateString -eq 'Responding' -and $PSItem.VirtualizationPlatformString -eq 'Microsoft Hyper-V'} | Sort-Object Name


} -ErrorAction Stop

if ($VMHosts) {

    Write-Output -InputObject "Getting MAC address ranges from $($VMHosts.Count) Hyper-V hosts retrieved from Virtual Machine Manager..."

    $output = @()

    foreach ($Computer in $VMHosts) {

        try {
 
            $output += Invoke-Command -ComputerName $Computer -ScriptBlock {

                Hyper-V\Get-VMHost -ErrorAction Stop | Select-Object Name, MacAddressMinimum, MacAddressMaximum

            } -Credential $NodeCredential -ErrorAction Stop
            

        }

        catch {

            "Failed to connect to $Computer : $($_.Exception.Message)"

        }


    }

    $Duplicates = $output | Group-Object -Property MacAddressMinimum | Where-Object Count -gt 1

    if ($Duplicates) {

        Write-Output "$($Duplicates.Count) duplicates found"

        $DuplicatesReport = @()

        foreach ($Duplicate in $Duplicates) {

            Write-Output "Hosts using MAC address minimum $($Duplicate.Name)"
            $Duplicate.Group.Name

            foreach ($VMHost in $Duplicate.Group.Name | Select-Object -SkipLast 1) {

                Write-Output "Generating new MAC address range for host $VMHost"

                $MacAddressMinimum = $Duplicate.Group.MacAddressMinimum[0]
                $MacAddressMaximum = $Duplicate.Group.MacAddressMaximum[0]

                do {
        
                    $NewOctets = '{0:x}{1:x}' -f (Get-Random -Minimum 0 -Maximum 15), (Get-Random -Minimum 0 -Maximum 15)
                    $NewMacAddressMinimum = ('00155D' + $NewOctets + $MacAddressMinimum.Substring(8, 4)).ToUpper()
                    $NewMacAddressMaximum = ('00155D' + $NewOctets + $MacAddressMaximum.Substring(8, 4)).ToUpper()

                }
                until ($NewMacAddressMinimum -notin $output.MacAddressMinimum)        

                $DuplicatesReport += [pscustomobject]@{
                    ComputerName              = $VMHost
                    ExistingMacAddressMinimum = $MacAddressMinimum
                    ExistingMacAddressMaximum = $MacAddressMaximum
                    NewMacAddressMinimum      = $NewMacAddressMinimum
                    NewMacAddressMaximum      = $NewMacAddressMaximum
                }

                Write-Output "Configuring new MAC address range $NewMacAddressMinimum - $NewMacAddressMaximum on host $VMHost"

                Invoke-Command -ComputerName $VMHost -ScriptBlock {

                    Write-Output "Connected to $($env:computername) - Configuring new MAC address range $using:NewMacAddressMinimum - $using:NewMacAddressMaximum"
                    Set-VMHost -MacAddressMinimum $using:NewMacAddressMinimum -MacAddressMaximum $using:NewMacAddressMaximum
    
                } -Credential $NodeCredential -ErrorAction Stop

            }

        }


    }

}

if ($MailNotificationRecipients -and $Duplicates) {

    Write-Output -InputObject "Sending e-mail notification to mail recipients $MailNotificationRecipients"

    $DuplicatesReport

    $body = $DuplicatesReport | ConvertTo-Html | Out-String

    $MailParameters = @{
        From       = 'Azure Automation <azure-automation@powershell.no>'
        Subject    = "Hyper-V host - duplicate MAC address ranges found and resolved"
        Body       = $body
        BodyAsHTML = $true
        SmtpServer = $SMTPServer
    }

    $To = @()
    $MailNotificationRecipients -split ',' | ForEach-Object {$To += $PSItem}

    $MailParameters.Add('To', $To)

    Send-MailMessage @MailParameters

}

Write-Output -InputObject "Runbook Repair-HyperVMACAddressRangeDuplicate finished $(Get-Date)"