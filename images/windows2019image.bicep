// https://learn.microsoft.com/en-us/azure/virtual-machines/linux/image-builder-json?tabs=bicep%2Cazure-powershell
param location string = resourceGroup().location
param name string = 'aib-${resourceGroup().name}'
param buildMaxTimeout int = 240
param identityType string = 'UserAssigned'
param vmSize string = 'Standard_D8s_v4'
param sourceValidationFlag bool = false
param sharedImageRegion string = location
param gallaryImageName string = 'sig${resourceGroup().name}ws2019'

var imageFolder = 'c:\\images'
var templateDirectory = '' 
var helper_script_folder = 'C:\\Program Files\\WindowsPowerShell\\Modules\\'

resource aibManagedID 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'string'
  location: location
  tags: {
    displayName: 'Image Builder'
  }
}

var userIdentityID = aibManagedID.id
var stagingResource = 'aib-staging-${resourceGroup().name}'

var gallaryImageDefineID = resourceId('Microsoft.Compute/galleries/images@2022-01-03', gallaryImageName)

resource ws2019ImageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2022-02-14' = {
  name: name
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
        name: 'FolderSetting1'
        type: 'File'
        sourceUri: '${templateDirectory}/scripts/ImageHelpers'
        destination: helper_script_folder
      }
    ]
    distribute: [
      {
        type: 'SharedImage'
        galleryImageId: gallaryImageDefineID
        runOutputName: 'string'
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
    stagingResourceGroup: stagingResource
    validate: {
      continueDistributeOnFailure: false
      inVMValidations: [
        {
          name: 'string'
          type: 'string'
          // For remaining properties, see ImageTemplateInVMValidator objects
        }
      ]
      sourceValidationOnly: sourceValidationFlag
    }
    vmProfile: {
      osDiskSizeGB: 127
      userAssignedIdentities: [
      ]
      vmSize: vmSize
      vnetConfig: {
      }
    }
  }
}
