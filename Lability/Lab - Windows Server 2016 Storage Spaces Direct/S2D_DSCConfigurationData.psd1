@{
    AllNodes = @(
        @{
            NodeName = '*';
            InterfaceAlias = 'Ethernet 2';
            DefaultGateway = '172.18.0.1';
            SubnetMask = 24;
            AddressFamily = 'IPv4';
            DnsServerAddress = '172.18.0.10';
            DomainName = 's2dlab.local';
            PSDscAllowPlainTextPassword = $true;
            CertificateFile = "C:\ProgramData\Lability\Certificates\LabClient.cer";
            Thumbprint = 'AAC41ECDDB3B582B133527E4DE0D2F8FEB17AAB2';
            PSDscAllowDomainUser = $true; # Removes 'It is not recommended to use domain credential for node X' messages
            Lability_SwitchName = 'Lab';
            Lability_ProcessorCount = 1;
            Lability_StartupMemory = 2GB;
            Lability_Media = '2016TP5_x64_Datacenter_EN_Gen1';
        }
        @{
            NodeName = 'DC1';
            IPAddress = '172.18.0.10';
            DnsServerAddress = '127.0.0.1';
            Role = 'DC';
            Lability_ProcessorCount = 2;
        }
                @{
            NodeName = 'S2D-Node1';
            IPAddress = '172.18.0.21';
            DnsServerAddress = '172.18.0.10';
            Role = 'S2D';
            Lability_ProcessorCount = 2;
        },
        @{
            NodeName = 'S2D-Node2';
            IPAddress = '172.18.0.22';
            DnsServerAddress = '172.18.0.10';
            Role = 'S2D';
            Lability_ProcessorCount = 2;
        },
        @{
            NodeName = 'S2D-Node3';
            IPAddress = '172.18.0.23';
            DnsServerAddress = '172.18.0.10';
            Role = 'S2D';
            Lability_ProcessorCount = 2;
        }
    );
    NonNodeData = @{
        Lability = @{
            EnvironmentPrefix = 'S2D-';
            Media = @();
            Network = @(
                @{ Name = 'Lab'; Type = 'Internal'; }
            );
            DSCResource = @(
                ## Download published version from the PowerShell Gallery
                @{ Name = 'xComputerManagement'; MinimumVersion = '1.3.0.0'; Provider = 'PSGallery'; }
                ## If not specified, the provider defaults to the PSGallery.
                @{ Name = 'xSmbShare'; MinimumVersion = '1.1.0.0'; }
                @{ Name = 'xNetworking'; MinimumVersion = '2.7.0.0'; }
                @{ Name = 'xActiveDirectory'; MinimumVersion = '2.9.0.0'; }
                @{ Name = 'xDnsServer'; MinimumVersion = '1.5.0.0'; }
                @{ Name = 'xDhcpServer'; MinimumVersion = '1.3.0.0'; }
                ## The 'GitHub# provider can download modules directly from a GitHub repository, for example:
                ## @{ Name = 'Lability'; Provider = 'GitHub'; Owner = 'VirtualEngine'; Repository = 'Lability'; Branch = 'dev'; }
            );
        };
    };
};