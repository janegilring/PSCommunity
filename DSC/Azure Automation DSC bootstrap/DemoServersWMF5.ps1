configuration DemoServersWMF5 {

  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Import-DscResource -ModuleName xComputerManagement

  # Common configuration for all DSC nodes
  node $AllNodes.NodeName {
  
        xComputer 'ComputerName' {

               Name = $node.NodeName

        }

  }
  
  # Role specific configuration for File Server role
  node $AllNodes.Where{$_.Role -eq 'FileServer'}.NodeName {
  
         WindowsFeature FileServer {

               Ensure = 'Present'
               Name = 'File-Services'

        }
  
  }

 }