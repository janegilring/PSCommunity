Import-Module 'C:\dashboards\UniversalDashboard\UniversalDashboard.psd1'

if (-not (Get-UDLicense)) {

    Set-UDLicense -License '<License><Terms>PD94bWwgdmVyc2lvbj0iMS4wIj8+DQo8TGljZW5zZVRlcm1zIHhtbG5zOnhzaT0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEtaW5zdGFuY2UiIHhtbG5zOnhzZD0iaHR0cDovL3d3dy53My5vcmcvMjAwMS9YTUxTY2hlbWEiPg0KICA8U3RhcnREYXRlPjIwMTctMDgtMjhUMTM6NDk6MDMuNDYxNjYyMSswMDowMDwvU3RhcnREYXRlPg0KICA8VXNlck5hbWU+amFuLmVnaWwucmluZ0BvdXRsb29rLmNvbTwvVXNlck5hbWU+DQogIDxQcm9kdWN0TmFtZT5Qb3dlclNoZWxsUHJvVG9vbHM8L1Byb2R1Y3ROYW1lPg0KICA8RW5kRGF0ZT4yMDE4LTA4LTI4VDEzOjQ5OjAzLjQ2MTY2MjErMDA6MDA8L0VuZERhdGU+DQogIDxTZWF0TnVtYmVyPjE8L1NlYXROdW1iZXI+DQogIDxJc1RyaWFsPmZhbHNlPC9Jc1RyaWFsPg0KPC9MaWNlbnNlVGVybXM+</Terms><Signature>c1WRfNunHJ7LN0RzDzM9TvCV2cuGCVbBasRMfUDwofSstOHRhNTxnw==</Signature></License>'

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