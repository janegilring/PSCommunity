Import-Module 'C:\dashboards\UniversalDashboard\UniversalDashboard.psd1'

if (-not (Get-UDLicense)) {

    Set-UDLicense -License '<License><Terms>add-your-licence here</Signature></License>'

}
$Colors = @{
    BackgroundColor = "#FF252525"
    FontColor = "#FFFFFFFF"
}

Start-UDDashboard -Content { 
    New-UDDashboard -Title "Employee registration form" -NavBarColor '#FF1c1c1c' -NavBarFontColor "#FF55b3ff" -BackgroundColor "#FF333333" -FontColor "#FF55b3ff" -Pages @( 
       New-UDPage -Url "/register/:id" -Endpoint {
            param($id)
                New-UDInput -Title "Register employee number" -Endpoint {
                    param($EmployeeNumber)

                        $WebHookUri = 'https://s2events.azure-automation.net/webhooks?token=abc123'  # Replace with actual token
                        $Date = (Get-Date -Format "MM/dd/yyyy HH:mm:ss").ToString()                        
                        $headers = @{"From"=$($env:username);"Date"=$Date}
                        
                        $parameters  =  @{ 
                            IFSEmployeeId = $EmployeeNumber
                            SharepointListItemId = $id
                        }
                        
                        $body = ConvertTo-Json -InputObject $parameters
                        
                        $response = Invoke-RestMethod -Method Post -Uri $WebHookUri -Headers $headers -Body $body                        
        
                        New-UDInputAction -Toast "Thank you for registering employee number $EmployeeNumber"
                    } 
       }
    )
} -Wait