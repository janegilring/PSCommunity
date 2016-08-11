function New-DemoVM {

  param (
    $VMName,
    $HyperVHost = 'localhost',
    $ISOPath,
    $MemoryMaximumBytes = 4GB,
    $MemoryStartupBytes = 1GB,
    $SwitchName = 'nat',
    $NewVMPath,
    $VMGeneration = '2',
    $NewVHDSizeBytes = 20GB,
    $CPUCount = '2',
    $TemplateVHDX,
    $DSCMetaConfiguration,
    $UnattendXml
    
  )


  if ($NewVMPath -eq $null) {
  
        $NewVMPath = (Get-VMHost -CimSession $HyperVHost).VirtualHardDiskPath
  
  }
  
 
  
  $NewVMParameters = @{

    CimSession = $HyperVHost
    Name = $VMName
    SwitchName = $SwitchName
    Path = $NewVMPath
    MemoryStartupBytes = $MemoryStartupBytes
    Generation = $VMGeneration

  }
   
   if ($TemplateVHDX -eq $null) {
    
     $NewVMParameters.Add('NewVHDPath',($NewVMPath + $VMName + '\' + $VMName + '_disk_1.vhdx'))
     $NewVMParameters.Add('NewVHDSizeBytes',$NewVHDSizeBytes)

   }
   
    
  $VM = New-VM @NewVMParameters

  $VM | Set-VMProcessor -Count $CPUCount
  $VM | Set-VM -DynamicMemory -MemoryMaximumBytes $MemoryMaximumBytes
  $VM | Set-VM -AutomaticStopAction ShutDown
 
   if ($TemplateVHDX) {

   Write-Host -Object "Creating differencing-disk based on specified template VHDX-file $TemplateVHDX"
    
     $NewVHDPath = ($NewVMPath + $VMName + '\' + $VMName + '_disk_1.vhdx')
     $null = New-VHD -Differencing -Path $NewVHDPath -ParentPath $TemplateVHDX -CimSession $HyperVHost

     switch ($VMGeneration) {
     '1' {$VM | Add-VMHardDiskDrive -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -Path $NewVHDPath}
     '2' {$VM | Add-VMHardDiskDrive -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0 -Path $NewVHDPath}
     }
     

  if ($VMGeneration -eq '2') {

        $VM | Set-VMFirmware -BootOrder $VM.HardDrives[0]

   }


   }
 
  if ($ISOPath) {
  
    $VM | Add-VMDvdDrive -Path $ISOPath
    Set-VMDvdDrive -VMName $VMName -Path $ISOPath -CimSession $HyperVHost
  
    $VM | Set-VMFirmware -BootOrder $VM.DVDDrives[0],$VM.HardDrives[0]
  
  }
 
 if ($DSCMetaConfiguration -or $UnattendXml) {
 
   function Get-UNCPath {param(	[string]$HostName,
        [string]$LocalPath)
     $NewPath = $LocalPath -replace(":","$")
     #delete the trailing \, if found
     if ($NewPath.EndsWith("\")) {
       $NewPath = [Text.RegularExpressions.Regex]::Replace($NewPath, "\\$", "")
     }
     "\\$HostName\$NewPath"
   }

   $NewVHDUNCPath = Get-UNCPath -HostName $HyperVHost -LocalPath $NewVHDPath
 
   $before = Get-Volume
   $VHDMount = Mount-DiskImage -ImagePath $NewVHDUNCPath -PassThru -StorageType VHDX
   $after = Get-Volume
   $VMSystemDrive = (Compare-Object $before $after -Passthru -Property DriveLetter | Where-Object DriveLetter).DriveLetter
   
   do
   {
   
     Write-Host "Waiting for VM system drive $VMSystemDrive to be available as a PSDrive" -ForegroundColor Yellow
   
     $drivetest = Get-PSDrive -Name $VMSystemDrive -Scope Global -ErrorAction Ignore
     
     Start-Sleep 2
     
   } until ($drivetest)
   
   
   $VMSystemPath = Join-Path -Path ($VMSystemDrive + ':\') -ChildPath Windows\System32\Configuration

   if ($UnattendXml) {
   
   $Destination = Join-Path -Path ($VMSystemDrive + ':\') -ChildPath Windows\Panther\unattend.xml
   
   Write-Host -Object "Injecting unattend-file $UnattendXml into VHDX-file"

   Copy-Item -Path $UnattendFile -Destination $Destination

   }

   if ($DSCMetaConfiguration) {


   $Destination = Join-Path -Path $VMSystemPath -ChildPath MetaConfig.mof

   Write-Host -Object "Injecting PowerShell DSC Meta Configuration $DSCMetaConfiguration into VHDX-file"
   
   Copy-Item -Path $DSCMetaConfiguration -Destination $Destination
   
   }
   

   Dismount-DiskImage -InputObject $VHDMount
 
 }

return $VM

}