<#
    .SYNOPSIS
    install-ad-modules.ps1

    .DESCRIPTION
    This script downloads and installs the required PowerShell modules to create and configure Active Directory Domain Controllers. 
    It also creates a self signed certificate to be uses with PowerShell DSC.
    
    .EXAMPLE
    .\install-ad-modules
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Output 'Installing NuGet Package Provider'
Try {
    Install-PackageProvider -Name 'NuGet' -MinimumVersion '2.8.5' -Force -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed to install NuGet Package Provider $_"
    Exit 1
}

Write-Output 'Setting PSGallery Respository to trusted'
Try {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed to set PSGallery Respository to trusted $_"
    Exit 1
}

Write-Output 'Installing the needed Powershell DSC modules for this Quick Start'
$Modules = @(
    @{
        Name = 'NetworkingDsc'
        Version = '8.2.0'
    },
    @{
        Name = 'ActiveDirectoryDsc'
        Version = '6.0.1'
    },
    @{
        Name = 'ComputerManagementDsc'
        Version = '8.4.0'
    },
    @{
        Name = 'xDnsServer'
        Version = '1.16.0.0'
    },
    @{
        Name = 'xActiveDirectory'
        Version = '3.0.0.0'
    }
)

Foreach ($Module in $Modules) {
    Try {
        Install-Module -Name $Module.Name -RequiredVersion $Module.Version -ErrorAction Stop
    } Catch [System.Exception] {
        Write-Output "Failed to Import Modules $_"
        Exit 1
    }
}

Write-Output 'Temporarily disabling Windows Firewall'
Get-NetFirewallProfile -ErrorAction Stop | Set-NetFirewallProfile -Enabled False -ErrorAction Stop

Write-Output 'Creating Directory for DSC Public Cert'
Try {
    New-Item -Path 'C:\AWSQuickstart\publickeys' -ItemType 'Directory' -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed to create publickeys directory $_"
    Exit 1
}

Write-Output 'Creating DSC Certificate to Encrypt Credentials in MOF File'
Try {
    $cert = New-SelfSignedCertificate -Type 'DocumentEncryptionCertLegacyCsp' -DnsName 'AWSQSDscEncryptCert' -HashAlgorithm 'SHA256' -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed to create self signed cert $_"
    Exit 1
}

Write-Output 'Exporting the public key certificate'
Try {
    $cert | Export-Certificate -FilePath 'C:\AWSQuickstart\publickeys\AWSQSDscPublicKey.cer' -Force -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed to copy self signed cert to publickeys directory $_"
    Exit 1
}

Write-Output 'Finding RAW Disk'

$Counter = 0
Do {
    $BlankDisk = Get-Disk -ErrorAction Stop | Where-Object { $_.partitionstyle -eq 'raw' }
    If (-not $BlankDisk) {
        $Counter ++
        Write-Output 'RAW Disk not found sleeping 10 seconds and will try again.'
        Start-Sleep -Seconds 10
    }
} Until ($BlankDisk -or $Counter -eq 12)

If ($Counter -ge 12) {
    Write-Output 'RAW Disk not found sleeping exitiing'
    Exit 1
}

Write-Output 'Data Volume not initialized attempting to bring online'
Try{
    Initialize-Disk -Number $BlankDisk.Number -PartitionStyle 'GPT' -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed attempting to bring online Data Volume $_"
    Exit 1
}

Start-Sleep -Seconds 5

Write-Output 'Data Volume creating new partition'
Try {
    $Null = New-Partition -DiskNumber $BlankDisk.Number -DriveLetter 'D' -UseMaximumSize -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed creating new partition $_"
    Exit 1
}

Start-Sleep -Seconds 5

Write-Output 'Data Volume formatting partition'
Try {
    $Null = Format-Volume -DriveLetter 'D' -FileSystem 'NTFS' -NewFileSystemLabel 'Data' -Confirm:$false -Force -ErrorAction Stop
} Catch [System.Exception] {
    Write-Output "Failed formatting partition $_"
    Exit 1
}