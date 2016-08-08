#region Basics

Install-Module -Name Lability

Get-Command -Module Lability

Get-Help about_Labililty
Get-Help about_ConfigurationData

Get-LabMedia | Format-Table imagename,id
 
Get-LabHostConfiguration
Get-LabHostDefault

Get-LabVMDefault
Set-LabVMDefault -SecureBoot $false

Start-LabHostConfiguration

#endregion

#region S2D lab

# Customize paths and configurations as needed

$DSCConfigurationPath = "~\Documents\WindowsPowerShell\Scripts\Hyper-V\Windows 10\Lability - S2D\S2DLab_DSCConfiguration.ps1"
$DSCConfigurationDataPath = "~\Documents\WindowsPowerShell\Scripts\Hyper-V\Windows 10\Lability - S2D\S2D_DSCConfigurationData.psd1"
$LabilityConfigurationDataPath = "~\Documents\WindowsPowerShell\Scripts\Hyper-V\Windows 10\Lability - S2D\S2D_LabilityConfigurationData.psd1"

psedit $DSCConfigurationPath
psedit $DSCConfigurationDataPath
psedit $LabilityConfigurationDataPath


$Credential = Get-Credential -UserName administrator -Message 'Specify credential for lab environment'

S2DLab -OutputPath C:\Lability\Configurations -ConfigurationData $DSCConfigurationDataPath

Start-LabConfiguration -ConfigurationData $LabilityConfigurationDataPath -Credential $Credential -Verbose

Start-Lab -ConfigurationData $LabilityConfigurationDataPath


# Checkpoint nodes (offline) when initial DSC consistency check is converged

Stop-Lab -ConfigurationData $LabilityConfigurationDataPath

Checkpoint-Lab -ConfigurationData -SnapshotName

Start-Lab -ConfigurationData $LabilityConfigurationDataPath


#region Data disks

# Not supported by Lability (xHyper-V) yet, thus data disks is added manually

$ConfigData.AllNodes | Where-Object nodename -like "S2D*" | foreach {

$diskNumber = '4'
$diskSizeinGB = 20GB

$VM = Get-VM $_.nodename
$newDir = Split-Path $VM.HardDrives.Path

    1..$diskNumber | % { $null = New-VHD -Path $newDir\$($VM.Name)_Disk_$_.VHDX -Dynamic -Size $diskSizeinGB}
    1..$diskNumber | % { $null = Add-VMHardDiskDrive -VMName $VM.Name -ControllerType SCSI -Path $newDir\$($VM.Name)_Disk_$_.VHDX}

}

#endregion

#region Enable Nested Virtualization for S2D nodes

$ConfigData.AllNodes | Where-Object nodename -like "S2D*" | foreach {

  Stop-VM -Name $_.nodename

  Set-VMProcessor -VMName $_.nodename -ExposeVirtualizationExtensions $true
  Set-VMNetworkAdapter -VMName $_.nodename -MacAddressSpoofing on

  Checkpoint-VM -Name $_.nodename -SnapshotName 'Enabled Nested Virtualization'

  Start-VM -Name $_.nodename


}

#endregion

#region Lab media

## Register existing Windows Server 2016 TP5 Datacenter 64bit English Evaluation VHD(X) media

# Need to use Gen 1 VM on Windows 10 Anniversary Update due to known bug with Windows Server 2016 TP5:
# https://social.technet.microsoft.com/Forums/windowsserver/en-US/8c0d9f19-873e-416d-9124-568ca43bf924/hyperv-configuration-version-80-windows-boot-manager-error-0xc0000603-in-windows-10-build143935?forum=WinServerPreview

$2016TP5_x64_Datacenter_EN_Gen1 = @{
    Id = '2016TP5_x64_Datacenter_EN_Gen1';
    Filename = '2016TP5_x64_Datacenter_EN_Gen1_082016.vhdx';
    Description = 'Windows Server 2016 TP5 Datacenter 64bit English Evaluation Patched 08/16';
    Architecture = 'x64';
    MediaType = 'VHD';
    Uri = 'file://C:\Hyper-V\2016TP5_x64_Datacenter_EN.vhdx';
    CustomData = @{
        PartitionStyle = 'MBR'; ## This creates a Gen1 VM
    }
}

Register-LabMedia @2016TP5_x64_Datacenter_EN_Gen1 -Force

#endregion

#region Cleanup

#Remove VMs when lab is not needed anymore
Remove-LabConfiguration -ConfigurationData $ConfigData

#endregion

#endregion