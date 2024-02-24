// https://learn.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json?tabs=bicep%2Cazure-powershell
param location string = resourceGroup().location
param aibName string = 'aib-${resourceGroup().name}'
param buildMaxTimeout int = 240
param identityType string = 'UserAssigned'
param vmSize string = 'Standard_D4_v4'
param sourceValidationFlag bool = false
param sharedImageRegion string = location
param gallaryImageName string = 'sig${resourceGroup().name}ws2022'
param imageTemplateName string = 'imageTemplate${resourceGroup().name}ws2022'
param AzureComputingGallery string = 'sig_windows_jpimages'
param languagePackStorageAccountName string = 'publicstorage'
param languagePackStorageResouceGroup string = resourceGroup().name
param languagePackISO string = 'mul_windows_server_2022_languages.iso'
 
var imageFolder = 'c:\\images'

resource aibManagedID 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: aibName
}

var userIdentityID = aibManagedID.id

resource lpstrorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: languagePackStorageAccountName
  scope: resourceGroup(languagePackStorageResouceGroup)
}

var lpstrorageURL = '${lpstrorage.properties.primaryEndpoints.blob}windowslangpack/${languagePackISO}'

resource gal 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: '${AzureComputingGallery}/${gallaryImageName}'
}

param date string = utcNow('yyyy.MM.ddHHmm')

var galleyImageVersion = '${gal.id}/versions/${date}'

resource ws2022ImageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-07-01' = {
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
        name: 'InstallLanguagePack'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2022/install-languagepack.ps1'
        sha256Checksum: '7aa9fff747d6fd19bb47d108b9ba4f014ce219bbd124d959d93148756143b83f'
        runElevated: true
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '5m'
      }
      {
        type: 'PowerShell'
        name: 'InstallLanguagePack'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2022/install-languagepack.ps1'
        sha256Checksum: 'b927319850cecb2fb87827b5e4d20f997e90b12fce053192e883b9385c4efc42'
        runElevated: true
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '5m'
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
            baseosimg: 'windows2022'
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
      sku: '2022-datacenter-azure-edition-hotpatch'
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
