configuration LogmanHyperV {

Import-DscResource -ModuleName PSCommunityDSCResources

    node localhost {

        Logman Hyper-V {

        DataCollectorSetName = 'Hyper-V'
        Ensure = 'Present'
        XmlTemplatePath = '\\domain.local\IT-Ops\Perfmon-templates\HyperV.xml'

        }

    }

}