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
@description('Git branch or commit SHA (only this segment is variable) used under raw.githubusercontent.com for script download.')
param repoBranch string = 'Windows2022jp'

@description('SHA256 of Initialize-VM.ps1 for integrity validation; leave blank to omit property.')
param initScriptChecksum string = '7148640BCCBC7B0A99975CBC006C1087F13BC31106B9ABFE21FA8A301E7ED552'
@description('SHA256 of install-jplangpack.ps1 for integrity validation; leave blank to omit.')
param installJpLangPackChecksum string = 'A590BC9AD1317D0DF92A0F028CCECB1C7695AD473C66F1D67E6752D21C123890'
@description('SHA256 of install-languagepack.ps1 for integrity validation; leave blank to omit.')
param configureLangChecksum string = '4F31472CDE5AD434B03C9AF05418C235FB6959470273829817D2A913D15E12ED'
@description('SHA256 of Finalize-VM.ps1 for integrity validation; leave blank to omit.')
param finalizeScriptChecksum string = 'A4D93AFB23F72FAFA8B13285CF56C31975E62A39BB536EC80A4AB6E23B620E32'
 
var imageFolder = 'c:\\images'
// Fixed repo coordinates; only branch/commit changes via repoBranch
var repoOwner = 'kkamegawa'
var repoName  = 'windowsjpimagebuilder'
var scriptBaseUri = 'https://raw.githubusercontent.com/${repoOwner}/${repoName}/${repoBranch}/images'

resource aibManagedID 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: aibName
}

var userIdentityID = aibManagedID.id

resource gal 'Microsoft.Compute/galleries/images@2023-07-03' existing = {
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
        scriptUri: '${scriptBaseUri}/common/Initialize-VM.ps1'
        sha256Checksum: empty(initScriptChecksum) ? null : initScriptChecksum
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
        type: 'PowerShell'
        name: 'InstallLanguagePack'
        runElevated: true
          scriptUri: '${scriptBaseUri}/Windows2022/install-jplangpack.ps1'
          sha256Checksum: empty(installJpLangPackChecksum) ? null : installJpLangPackChecksum
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '5m'
      }
      {
        type: 'PowerShell'
        name: 'InstallLanguagePack'
        runElevated: true
          scriptUri: '${scriptBaseUri}/Windows2022/install-languagepack.ps1'
          sha256Checksum: empty(configureLangChecksum) ? null : configureLangChecksum
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
        scriptUri: '${scriptBaseUri}/common/Finalize-VM.ps1'
        sha256Checksum: empty(finalizeScriptChecksum) ? null : finalizeScriptChecksum
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
