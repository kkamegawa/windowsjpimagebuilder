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
        name: 'InitializeVM'
        type: 'PowerShell'
        runElevated: true
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/Initialize-VM.ps1'
        sha256Checksum: '7148640bccbc7b0a99975cbc006c1087f13bc31106b9abfe21fa8a301e7ed552'
      }
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
        sha256Checksum: '467cfeb5727ba216bce70b2074f214c09b201b0de005e142eaa996b60ddd0f87'
      }
      {
        type: 'PowerShell'
        name: 'InstallNET48FX'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2019/Install-NET48.ps1'
        sha256Checksum: '153558fb05f977ed20030925fc02d9aed0c56fb9cdb405a5771d81709fcec44a'
      }
      {
        type: 'PowerShell'
        name: 'ChangeLanguage1'
        inline: [
          'Set-WinUserLanguageList -LanguageList ja-JP,en-US -Force'
          '$LangList = Get-WinUserLanguageList'
          '$MarkedLang = $LangList | where LanguageTag -eq "en-US"'
          '$LangList.Remove($MarkedLang)'
          'Set-WinUserLanguageList $LangList -Force'
        ]
        runElevated: false
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '5m'
      }
      {
        type: 'File'
        name: 'SetJaJPWelcome'
        sourceUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/ja-jp-welcome.reg'
        destination: '${imageFolder}\\ja-jp-welcome.reg'
      }
      {
        type: 'File'
        name: 'SetJaJPDefault'
        sourceUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/ja-jp-default.reg'
        destination: '${imageFolder}\\ja-jp-default.reg'
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
        type: 'PowerShell'
        name: 'ChangeDefaultLanguage'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/load_registry.ps1'
        runElevated: false
        sha256Checksum: '3ed09b0da5a922f694a2de13f9236a71619f651b2421fe975c448596ac31a806'
      }
      {
        type: 'WindowsRestart'
        restartTimeout: '10m'
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
        sha256Checksum: '806402bfae838edf0938937b3b612ae4b03e858fc5950e43742b30cf106589b2'
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
