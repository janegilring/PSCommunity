enum Ensure
{
    Absent
    Present
}

[DscResource()]
class Logman
{

    [DscProperty(Key)]
    [string]$DataCollectorSetName

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(Mandatory)]
    [string] $XmlTemplatePath

    #Replaces Get-TargetResource
    [Logman] Get()
    {

 $logmanquery = (logman.exe query $this.DataCollectorSetName | Select-String -Pattern Name) -replace 'Name:                 ', ''

  if ($logmanquery -contains $this.DataCollectorSetName) 
  {
    $this.Ensure = $true
  }
  else 
  {
    $this.Ensure = $false
  }


  $returnValue = @{
    DataCollectorSetName = $this.DataCollectorSetName
    Ensure               = $this.Ensure
    XmlTemplatePath      = $this.XmlTemplatePath
  }

  return $returnValue
 
    }

    #Replaces Set-TargetResource
    [void] Set()
    {
 
   if( $this.Ensure -eq 'Present' )
  {
    if (Test-Path -Path $this.XmlTemplatePath) 
    {
      Write-Verbose -Message "Importing logman Data Collector Set $($this.DataCollectorSetName) from Xml template $($this.XmlTemplatePath)"

      $null = logman.exe import -n $this.DataCollectorSetName -xml $this.XmlTemplatePath
    } else 
    {
      Write-Verbose -Message "$($this.XmlTemplatePath) not found or temporary inaccessible, trying again on next consistency check"
    }
  }
  elseif( $this.Ensure -eq 'Absent' ) 
  {
    Write-Verbose -Message "Removing logman Data Collector Set $($this.DataCollectorSetName)"

    $null = logman.exe delete $this.DataCollectorSetName
  }


    }
 
    #Replaces Test-TargetResource
    [bool] Test()
    {

      $logmanquery = (logman.exe query $this.DataCollectorSetName | Select-String -Pattern Name) -replace 'Name:                 ', ''

  if ($logmanquery -contains $this.DataCollectorSetName) 
  {
    Write-Verbose -Message "Data Collector $($this.DataCollectorSetName) exists"

    if( $this.Ensure -eq 'Present' ) 
    {
      return $true
    }
    elseif ( $this.Ensure -eq 'Absent' ) 
    {
      return $false
    }
  }
  else 
  {
    Write-Verbose -Message "Data Collector $($this.DataCollectorSetName) does not exist"

    if( $this.Ensure -eq 'Present' ) 
    {
      return $false
    }
    elseif ( $this.Ensure -eq 'Absent' ) 
    {
      return $true
    }
  }
 
    }
 
 }