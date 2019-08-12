#Requires -Modules virtualmachinemanager
#Requires -Modules SqlServer

param(
    $VMMSQLServerName = 'sql01.contoso.com',
    $VMMDatabaseName = 'VirtualManagerDB'
)

    <#
       .SYNOPSIS
       Clean-VMMDatabaseOrphanedHost.ps1 is a PowerShell script to remove orphaned hosts from the System Center Virtual Machine Manager database.
       .DESCRIPTION
       Often when removing and re-adding hosts to Virtual Machine Manager, not all data is removed after removing the hosts.
       This can lead to issues when trying to re-add the host using Bare Metal Deployment, such as:

       "Error (21201)
        Another machine with the same SMBIOS GUID is found.
        Recommended Action
        An SMBIOS GUID should uniquely identify the machine. Provide the correct value or contact the machine manufacturer to help update the hardware with correct information."

        The VirtualMachineManager module is available on machines where the Virtual Machine Manager administrator console is installed.
        The SQL Server module can be installed from the PowerShell Gallery:
        Install-Module -Name SqlServer

        Note that directly manipulating the VMM database is not supported by Microsoft, use this script on your own risk.
        Doing a manual backup of the database before running the script is highly recommended.

            Required version: Windows PowerShell 5.0 or later
            Required modules: VirtualMachineManager, SqlServer
            Required privileges: Read-permission in SC VMM

       .EXAMPLE
       C:\Scripts\Clean-VMMDatabaseOrphanedHost.ps1 -VMMSQLServerName VMMSQL01.contoso.com -VMMDatabaseName = 'ContosoVMMDB'
   #>

$VMMSQLDBPhysicalMachineTable = Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database $VMMDatabaseName -Query 'SELECT * FROM tbl_PMM_PhysicalMachine' | Select-Object PhysicalMachineId, BMCAddress, SmBiosGuid

$VMMHosts = Get-SCVMHost | Select-Object Name, @{n = 'SmBiosGuid'; e = { $PSItem.PhysicalMachine } }

$OrphanedHostsInVMMSQLDB = Compare-Object -ReferenceObject $VMMSQLDBPhysicalMachineTable -DifferenceObject $VMMHosts -Property SmBiosGuid | Where-Object SideIndicator -eq '<=' | Where-Object {$PSItem.SmBiosGuid.GetType().Name -ne "DBNull"}


if ($OrphanedHostsInVMMSQLDB) {

    Write-Host "Found orhpaned hosts in VMM - removing" -ForegroundColor Yellow

    $OrphanedHostsInVMMSQLDB.SmBiosGuid

    foreach ($OrphanedHost in $OrphanedHostsInVMMSQLDB.SmBiosGuid) {

        $OrphanedHost = $OrphanedHost.Guid.ToUpper()

        $PhysicalMachineId = (Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database $VMMDatabaseName -Query "SELECT * FROM tbl_PMM_PhysicalMachine WHERE (SmBiosGuid = '$OrphanedHost')").PhysicalMachineId.Guid

        $StFileServerNodeId = (Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database $VMMDatabaseName -Query "SELECT * FROM tbl_ST_StorageFileServerNode WHERE (PhysicalMachineId = '$PhysicalMachineId')").StFileServerNodeId.Guid

        $SasHbaId = (Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database $VMMDatabaseName -Query "SELECT * FROM tbl_ADHC_HostBusAdapter WHERE (StorageFileServerNodeID = '$StFileServerNodeId')").HbaId.Guid

        Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database VirtualManagerDB -Query "DELETE FROM tbl_ADHC_HostSASHba WHERE (SASHbaId = '$SasHbaId')"

        Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database VirtualManagerDB -Query "DELETE FROM tbl_ADHC_HostBusAdapter WHERE (StorageFileServerNodeID = '$StFileServerNodeId')"

        Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database VirtualManagerDB -Query "DELETE FROM tbl_ADHC_HostNetworkAdapter WHERE (PhysicalMachineId = '$PhysicalMachineId')"

        Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database VirtualManagerDB -Query "DELETE FROM tbl_ST_StorageFileServerNode WHERE (PhysicalMachineId = '$PhysicalMachineId')"

        Invoke-Sqlcmd -ServerInstance $VMMSQLServerName -Database VirtualManagerDB -Query "DELETE FROM tbl_PMM_PhysicalMachine WHERE (SmBiosGuid = '$OrphanedHost')"

    }

} else {

    Write-Host "No orhpaned hosts found in VMM" -ForegroundColor Green

}