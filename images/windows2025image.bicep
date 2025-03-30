// https://learn.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json?tabs=bicep%2Cazure-powershell
param location string = resourceGroup().location
param aibName string = 'aib-${resourceGroup().name}'
param buildMaxTimeout int = 240
param identityType string = 'UserAssigned'
param vmSize string = 'Standard_D4_v4'
param sourceValidationFlag bool = false
param sharedImageRegion string = location
param gallaryImageName string = 'sig${resourceGroup().name}ws2025'
param imageTemplateName string = 'imageTemplate${resourceGroup().name}ws2025'
param AzureComputingGallery string = 'sig_windows_jpimages'
 
var imageFolder = 'c:\\images'

resource aibManagedID 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: aibName
}

var userIdentityID = aibManagedID.id

resource gal 'Microsoft.Compute/galleries/images@2024-03-03' existing = {
  name: '${AzureComputingGallery}/${gallaryImageName}'
}

param date string = utcNow('yyyy.MM.ddHHmm')

var galleyImageVersion = '${gal.id}/versions/${date}'

resource ws2022ImageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01' = {
  name: imageTemplateName
  location: location
  tags: {
    displayName: 'Image Builder'
  }
  identity: {
    type: identityType
    userAssignedIdentities: {
      '${userIdentityID}': {}
    }
  }
  properties: {
    buildTimeoutInMinutes: buildMaxTimeout
    customize: [
      {
        name: 'InitializeVM'
        type: 'PowerShell'
        runElevated: true
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/Initialize-VM.ps1'
        sha256Checksum: '7148640bccbc7b0a99975cbc006c1087f13bc31106b9abfe21fa8a301e7ed552'
      }
      {
        type: 'PowerShell'
        name: 'Install .NET Framework 4.8.1'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2025/Install-NET481.ps1'
        sha256Checksum: 'd076779c2234ffe2c7b8a61865ef2d51ad6ba8036b92cb8861189c9ea71cc79e'
        runElevated: true
      }
      {
        type: 'PowerShell'
        name: 'Install .NET Framework 4.8.1 Language Pack'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2025/Install-NET481langpack.ps1'
        sha256Checksum: '670ea4909a9ec5f6323d6c7df50bf906861fc3abd21bc70e8a141f3db64be58c'
        runElevated: true
      }
      {
        name: 'remove 65330/udp port'
        type: 'PowerShell'
        runElevated: true
        inline: [
          'netsh int ipv4 add excludedportrange udp 65330 1 persistent'
        ]
      }
      {
        name: 'Install Language Pack'
        type: 'PowerShell'
        runElevated: true
        inline: [
          'install-language ja-jp -CopyTosettings'
        ]
      }
      {
        type: 'PowerShell'
        name: 'Set ja-jp as default'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2025/install-languagepack.ps1'
        sha256Checksum: 'b927319850cecb2fb87827b5e4d20f997e90b12fce053192e883b9385c4efc42'
        runElevated: true
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '30m'
      }
      {
        type: 'WindowsUpdate'
        searchCriteria: 'IsInstalled=0'
        filters: [
          'exclude:$_.Title -like \'*Preview*\''
          'include:$true'
        ]
        updateLimit: 30
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '40m'
      }
      {
        name: 'FinalizeVM'
        type: 'PowerShell'
        runElevated: true
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/Finalize-VM.ps1'
        sha256Checksum: 'a4d93afb23f72fafa8b13285cf56c31975e62a39bb536ec80a4ab6e23b620e32'
      }
      {
        type: 'PowerShell'
        name: 'cleanup'
        inline: [
          'remove-item -path ${imageFolder} -recurse -force'
        ]
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: galleyImageVersion
        runOutputName: 'winclient01'
        artifactTags: {
            source: 'azureVmImageBuilder'
            baseosimg: 'windows2025'
        }
        replicationRegions: [
          sharedImageRegion
        ]
      }
    ]
    source: {
      type: 'PlatformImage'
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    validate: {
      continueDistributeOnFailure: false
      inVMValidations: [
        {
          name: 'string'
          type: 'PowerShell'
          inline: [
            'Get-ChildItem -Path ${imageFolder}'
          ]
        }
      ]
      sourceValidationOnly: sourceValidationFlag
    }
    vmProfile: {
      osDiskSizeGB: 127
      userAssignedIdentities: [
      ]
      vmSize: vmSize
    }
  }
}
