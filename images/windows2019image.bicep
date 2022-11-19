// https://learn.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json?tabs=bicep%2Cazure-powershell
param location string = resourceGroup().location
param aibName string = 'aib-${resourceGroup().name}'
param buildMaxTimeout int = 240
param identityType string = 'UserAssigned'
param vmSize string = 'Standard_D8s_v4'
param sourceValidationFlag bool = false
param sharedImageRegion string = location
param gallaryImageName string = 'sig${resourceGroup().name}ws2019'
param imageTemplateName string = 'imageTemplate${resourceGroup().name}ws2019'
param AzureComputingGallery string = 'sig_windows_jpimages'
 
var imageFolder = 'c:\\images'

resource aibManagedID 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: aibName
}

var userIdentityID = aibManagedID.id

var gallaryImageDefineID = format('/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/galleries/{2}/images/{3}', subscription().subscriptionId, resourceGroup().name, AzureComputingGallery, gallaryImageName)

resource ws2019ImageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
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
        name: 'startup'
        type: 'PowerShell'
        inline: [
          'New-Item -ItemType Directory -Path ${imageFolder} -force'
        ]
        runElevated: false
      }
      {
        type: 'PowerShell'
        name: 'CopyLangPackScripts'
        runElevated: true
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2019/install-languagepack.ps1'
      }
      {
        type: 'PowerShell'
        name: 'InstallLangPack'
        inline: [
          'import-module ${imageFolder}\\install-languagepack.ps1'
          'Install-LanguagePack -imageType 0 -folder ${imageFolder}'
        ]
      }
      {
        type: 'WindowsUpdate'
        searchCriteria: 'IsInstalled=0'
        filters: [
          'exclude:$_.Title -like \'*Preview*\''
          'include:$true'
        ]
        updateLimit: 20
      }
      {
        type: 'WindowsRestart'
        restartCommand: 'shutdown /r /f /t 0'
        restartCheckCommand: 'echo Azure-Image-Builder-Restarted-the-VM  > c:\\buildArtifacts\\azureImageBuilderRestart.txt'
        restartTimeout: '10m'
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
        galleryImageId: gallaryImageDefineID
        runOutputName: 'winclient01'
        artifactTags: {
            source: 'azureVmImageBuilder'
            baseosimg: 'windows2019'
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
      sku: '2019-Datacenter'
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
