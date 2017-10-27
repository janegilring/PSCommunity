#requires -version 2.0

function Publish-SfBContactInformation {

    <#
.Synopsis
   Publish-SfBContactInformation is a PowerShell function to configure a set of settings in the Skype for Business client.
.DESCRIPTION
   The purpose of Publish-SfBContactInformation is to demonstrate how PowerShell can be used to interact with the Lync SDK.
   Tested with Lync 2013 only.
   Prerequisites: Lync 2013 SDK - http://www.microsoft.com/en-us/download/details.aspx?id=36824
.EXAMPLE
   Publish-SfBContactInformation -Availability Available
.EXAMPLE
    Publish-SfBContactInformation -Availability Away
.EXAMPLE
    Publish-SfBContactInformation -Availability "Off Work" -ActivityId off-work
.EXAMPLE
    Publish-SfBContactInformation -PersonalNote test
.EXAMPLE
    Publish-SfBContactInformation -Availability Available -PersonalNote ("Quote of the day: " + (Get-QOTD))
.EXAMPLE
    Publish-SfBContactInformation -Location Work
.NOTES
   For more information, see the related blog post at blog.powershell.no
.FUNCTIONALITY
   Provides a function to configure Availability, ActivityId and PersonalNote for the Microsoft Lync client.
#>

    Param
    (
        # Availability state as string
        [ValidateSet("Appear Offline", "Available", "Away", "Busy", "Do Not Disturb", "Be Right Back", "Off Work")]
        [string]
        $Availability,
        # ActivityId as string
        [string]
        $ActivityId,
        # String value to be configured as personal note in the Skype for Business client
        [string]
        $PersonalNote,
        [int]$CustomActivityId,
        # String value to be configured as location in the Skype for Business client
        [string]
        $Location
    )

    if (-not (Get-Module -Name Microsoft.Lync.Model)) {

        try {

            $ModulePath1 = (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath “Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll”)
            $ModulePath2 = (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath “Microsoft Office 2013\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll”)

            if (Test-Path -Path $ModulePath1) {
                Import-Module -Name $ModulePath1 -ErrorAction Stop
            }
            else {
                Import-Module -Name $ModulePath2 -ErrorAction Stop
            }

        }
        catch {
            Write-Warning "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
            break
        }

    }

    $Client = [Microsoft.Lync.Model.LyncClient]::GetClient()

    if ($Client.State -eq "SignedIn") {

        $Self = $Client.Self
        $ContactInfo = New-Object 'System.Collections.Generic.Dictionary[Microsoft.Lync.Model.PublishableContactInformationType, object]'

        switch ($Availability) {
            "Available" {$AvailabilityId = 3000}
            "Appear Offline" {$AvailabilityId = 18000}
            "Away" {$AvailabilityId = 15000}
            "Busy" {$AvailabilityId = 6000}
            "Do Not Disturb" {$AvailabilityId = 9000}
            "Be Right Back" {$AvailabilityId = 12000}
            "Off Work" {$AvailabilityId = 15500}
        }

        if ($CustomActivityId) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::CustomActivityId, $CustomActivityId)
        }
        else {

            if ($Availability) {
                $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::Availability, $AvailabilityId)
            }

            if ($ActivityId) {
                $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::ActivityId, $ActivityId)
            }

        }

        if ($PersonalNote) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::PersonalNote, $PersonalNote)
        }

        if ($Location) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::LocationName, $Location)
        }

        if ($ContactInfo.Count -gt 0) {

            $Publish = $Self.BeginPublishContactInformation($ContactInfo, $null, $null)
            $self.EndPublishContactInformation($Publish)

        }
        else {

            Write-Warning "No options supplied, no action was performed"

        }


    }
    else {

        Write-Warning "Skype for Business client is not running or signed in, no action was performed"

    }


}