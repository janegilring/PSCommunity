# This script is an example part of an article on www.powershellmagazine.com

Import-Module DataProtectionManager

$csv = Import-Csv C:\temp\infisiert.csv -Delimiter ';'

$pg = Get-ProtectionGroup -DPMServerName DPM01 | where FriendlyName -eq 'File cluster'
$ps = Get-DPMProductionServer | where servername -eq FILE01
$ds = Get-Datasource -ProtectionGroup $pg | where DisplayPath -eq 'F:\Public'

$dateDeleted = Get-Date 21-01-2015
$recoveryDate = Get-Date $dateDeleted.AddDays(-1).ToShortDateString()
$ro = New-RecoveryOption -TargetServer FILE01 -RecoveryLocation OriginalServer -FileSystem -OverwriteType OverWrite -RecoveryType Recover

$i = 0
$ri = @()

foreach ($file in $csv) {

$i++
Write-Progress -Activity 'Restoring files' -Status "Percent completed: $($i / $csv.count * 100)" -PercentComplete (($i / $csv.count)  * 100)

Write-Host "Processing file $i of $($csv.count)"

$so = New-SearchOption -FromRecoveryPoint $recoveryDate.AddDays(-1).ToShortDateString() -ToRecoveryPoint $recoveryDate.ToShortDateString() -SearchDetail FilesFolders -SearchType ExactMatch -Location $file.Directory -SearchString $file.Name
$ri +=  Get-RecoverableItem -Datasource $ds -SearchOption $so

}

$recoveryJob = Restore-DPMRecoverableItem -RecoverableItem $ri -RecoveryOption $ro