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
        name: 'InstallLanguagePack'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2019/install-languagepack.ps1'
      }
      {
        type: 'PowerShell'
        name: 'ChangeLanguage1'
        inline: [
          'Set-WinUserLanguageList -LanguageList ja-JP,en-US -Force'
          'Set-WinDefaultInputMethodOverride -InputTip "0411:00000411"'
        ]
        runElevated: false
      }
      {
        type: 'File'
        name: 'SetJaJPDefault'
        sourceUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/ja-jp-default.reg'
        destination: '${imageFolder}\\ja-jp-default.reg'
      }
      {
        type: 'File'
        name: 'SetJaJPWelcome'
        sourceUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/ja-jp-welcome.reg'
        destination: '${imageFolder}\\ja-jp-welcome.reg'
      }
      {
        type: 'PowerShell'
        name: 'ChangeDefaultLanguage'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/load_registry.ps1'
        runElevated: false
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '5m'
      }
      {
        type: 'PowerShell'
        name: 'ChangeLanguage2'
        inline: [
          'Set-WinUILanguageOverride -Language ja-JP'
          'Set-WinCultureFromLanguageListOptOut -OptOut $False'
          'Set-WinHomeLocation -GeoId 0x7A'
          'Set-WinSystemLocale -SystemLocale ja-JP'
          'Set-TimeZone -Id "Tokyo Standard Time"'
          'Set-Culture ja-JP'
        ]
        runElevated: false
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
        type: 'PowerShell'
        inline: [
            'while ((Get-Service RdAgent).Status -ne \'Running\') { Start-Sleep -s 5 }'
            'while ((Get-Service WindowsAzureGuestAgent).Status -ne \'Running\') { Start-Sleep -s 5 }'
            '& net start WindowsAzureGuestAgent'
            '& net start rdagent'
        ]
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
