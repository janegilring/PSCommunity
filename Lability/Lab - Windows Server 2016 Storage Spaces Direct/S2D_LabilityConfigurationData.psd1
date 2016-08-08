@{
    AllNodes = @(
        @{
            NodeName = 'DC1';
            Lability_ProcessorCount = 2;
            Lability_SwitchName = 'Lab';
            Lability_Media = '2016TP5_x64_Datacenter_EN_Gen1';
            Lability_BootOrder = '1';
            Lability_BootDelay = '60';
        },
        @{
            NodeName = 'S2D-Node1';
            Lability_ProcessorCount = 1;
            Lability_SwitchName = 'Lab';
            Lability_Media = '2016TP5_x64_Datacenter_EN_Gen1';
            Lability_BootOrder = '1';
        },
        @{
            NodeName = 'S2D-Node2';
            Lability_ProcessorCount = 1;
            Lability_SwitchName = 'Lab';
            Lability_Media = '2016TP5_x64_Datacenter_EN_Gen1';
            Lability_BootOrder = '1';
        },
        @{
            NodeName = 'S2D-Node3';
            Lability_ProcessorCount = 1;
            Lability_SwitchName = 'Lab';
            Lability_Media = '2016TP5_x64_Datacenter_EN_Gen1';
            Lability_BootOrder = '1';
        }
    )
    NonNodeData = @{
        Lability = @{
            Network = @(
                @{ Name = 'Lab'; Type = 'Internal'; }
            )
        }
    }
}