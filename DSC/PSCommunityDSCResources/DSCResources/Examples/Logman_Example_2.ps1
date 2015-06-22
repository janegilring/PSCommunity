configuration LogmanHyperV {

Import-DscResource -ModuleName PSCommunityDSCResources

node localhost {


Script ScriptExample
{
    SetScript = { 

try {

$Source = Get-Item -Path '\\domain.local\IT-Ops\Perfmon-templates\HyperV.xml' -ErrorAction Stop
$Destination = Get-Item -Path 'C:\PerfLogs\Templates\HyperV.xml' -ErrorAction Stop

if ($Source.LastWriteTime -ne $Destination.LastWriteTime) {

Write-Verbose -Message "LastWriteTime for $($Source.FullName) and $($Destination.FullName) is different, removing Data Set Collector"

if (((logman query 'Hyper-V' | Select-String -Pattern Status) -replace 'Status:               ','')[0] -ne 'Running') {

$null = Invoke-Expression -Command 'logman delete Hyper-V' -ErrorAction SilentlyContinue

}


}

}
catch {

Write-Verbose -Message "Failed to access LastWriteTime for either $($Source.FullName) or $($Destination.FullName), unable to test whether local Data Collector Set template is updated"


}

    }
    TestScript = { 
    
try {

$Source = Get-Item -Path '\\domain.local\IT-Ops\Perfmon-templates\HyperV.xml' -ErrorAction Stop
$Destination = Get-Item -Path 'C:\PerfLogs\Templates\HyperV.xml' -ErrorAction Stop

if ($Source.LastWriteTime -ne $Destination.LastWriteTime) {

Write-Verbose -Message "LastWriteTime for $($Source.FullName) and $($Destination.FullName) is different, removing Data Set Collector"

return $false

} else {

return $true

}

}
catch {

Write-Verbose -Message "Failed to access LastWriteTime for either $($Source.FullName) or $($Destination.FullName), unable to test whether local Data Collector Set template is updated"

return $true

}
    
     }
    GetScript = {
    
try {

$Source = Get-Item -Path '\\domain.local\IT-Ops\Perfmon-templates\HyperV.xml' -ErrorAction Stop
$Destination = Get-Item -Path 'C:\PerfLogs\Templates\HyperV.xml' -ErrorAction Stop


$returnValue = [ordered]@{
		SourceLastWriteTime = $Source.LastWriteTime
        SourceFullName = $Source.FullName
		DestinationLastWriteTime = $Destination.LastWriteTime
        DestinationFullName = $Destination.FullName
	}

#$returnValue

}
catch {

Write-Verbose -Message "Failed to access LastWriteTime for either $($Source.FullName) or $($Destination.FullName), unable to test whether local Data Collector Set template is updated"


}
    
     }          
}


File PerfLogs{

DestinationPath = 'C:\PerfLogs'
Type = 'Directory'
Ensure = 'Present'

}

File Templates {

DestinationPath = 'C:\PerfLogs\Templates'
Type = 'Directory'
Ensure = 'Present'
DependsOn = '[File]PerfLogs'

}

File LogmanTemplate {

SourcePath = '\\domain.local\IT-Ops\Perfmon-templates\HyperV.xml'
DestinationPath = 'C:\PerfLogs\Templates\HyperV.xml'
Type = 'File'
Ensure = 'Present'
MatchSource = $true
Checksum = 'ModifiedDate'

DependsOn = '[File]Templates'

}

Logman Hyper-V {

DataCollectorSetName = 'Hyper-V'
Ensure = 'Present'
XmlTemplatePath = 'C:\PerfLogs\Templates\HyperV.xml'

DependsOn = '[File]LogmanTemplate'

}


}

}
