#By MVP Ståle Hansen (http://msunified.net) with modifications by Jan Egil Ring
#Pomodoro function by Nathan.Run() http://nathanhoneycutt.net/blog/a-pomodoro-timer-in-powershell/
#Lync Custom states by Jan Egil Ring http://blog.powershell.no/2013/08/08/automating-microsoft-lync-using-windows-powershell/
#Note: for desktops you need to enable presentation settings in order to suppress email alerts, by MVP Robert Sparnaaij: https://msunified.net/2013/11/25/lock-down-your-lync-status-and-pc-notifications-using-powershell/

Function Start-Pomodoro {
    Param (
        #Duration of your Pomodoro Session
        [int]$Minutes = 25
    )
      
    #Add the path your wave file here
    $StartWave = "C:\Windows\Media\Windows Proximity Connection.wav"
    $EndWave = "C:\Windows\Media\Windows Proximity Notification.wav"
    $stop = $False
 
    if (!(Test-Path $StartWave)) {Write-host Start Wave file not found; $stop = "True"}
    if (!(Test-Path $EndWave)) {Write-host End Wave file not found; $stop = "True"}
    if ($Stop -eq $True) {Read-host "Wav files could not be found, press enter to continue or crl+c to exit"}
  
  
    $seconds = $Minutes * 60
    $delay = 1 #seconds between ticks
    $PersonalNote = "Will be available at $(Get-Date $((Get-Date).AddMinutes($Minutes)) -Format HH:mm)"
  
    #Set do-not-disturb Pomodoro Foucs custom presence, where 1 is my pomodoro custom presence state
    Publish-SfBContactInformation -CustomActivityId 1 -PersonalNote $PersonalNote

    Write-Host -Object "Updated Skype for Business client status to custom activity 1 (Pomodoro Focus) and personal note: $PersonalNote" -ForegroundColor Green
  
    #Setting computer to presentation mode, will suppress most types of popups
    presentationsettings /start
  
    #Starting music, remember to change filepath to your wav file
    $player = New-Object System.Media.SoundPlayer $StartWave -ErrorAction SilentlyContinue
    1..2 | % { $player.Play() ; sleep -m 3400 }
  
    #Counting down to end of Pomodoro
    for ($i = $seconds; $i -gt 0; $i = $i - $delay) {
        $percentComplete = 100 - (($i / $seconds) * 100)
        Write-Progress -SecondsRemaining $i `
            -Activity "Pomodoro Focus sessions" `
            -Status "Time remaining:" `
            -PercentComplete $percentComplete
        Start-Sleep -Seconds $delay
  
    }
  
    #Stopping presentation mode to re-enable outlook popups and other notifications
    presentationsettings /stop
  
    #Pomodoro session finished, resetting status and personal note, availability 1 will reset the Lync status
    Publish-SfBContactInformation -PersonalNote ' '
    Publish-SfBContactInformation -Availability Available
  

    #Playing end of focus session song\alarm, 6 times
    $player = New-Object System.Media.SoundPlayer $EndWave -ErrorAction SilentlyContinue
    1..2 | % { $player.Play() ; sleep -m 1400 }
  
    Write-Host -Object "Pomodoro Focus session ended" -ForegroundColor Green

}