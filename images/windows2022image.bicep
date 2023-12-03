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
        name: 'startup'
        type: 'PowerShell'
        inline: [
          'New-Item -ItemType Directory -Path ${imageFolder} -force'
          '$outputPath = join-path ${imageFolder} -childpath langpack.iso'
          'invoke-WebRequest -uri ${lpstrorageURL} -outfile $outputPath -usebasicparsing'

        ]
        runElevated: false
      }
      {
        type: 'PowerShell'
        name: 'InstallLanguagePack'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2022/install-languagepack.ps1'
        sha256Checksum: '9b5f273c84eb4d1a43d36c143325dc29a7b470107dfd38bb94d099001149a679'
      }
      {
        type: 'PowerShell'
        name: 'InstallNET481FX'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2022/Install-NET481.ps1'
        sha256Checksum: 'deb45ddf190e7d89f58cad38e4873bbc201a723106c660097aa32f40f241fdc5'
      }
      {
        type: 'File'
        name: 'Copysysprep'
        sourceUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/common/sysprep.ps1'
        destination: 'c:\\DeprovisioningScript.ps1'
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
        type: 'PowerShell'
        name: 'InstallNET481FXjp'
        scriptUri: 'https://raw.githubusercontent.com/kkamegawa/windowsjpimagebuilder/main/images/Windows2022/Install-NET481langpack.ps1'
        sha256Checksum: 'bd586e7c3691ca768e8dc049c8fd58cca935bc4e85b5d34bf5b797960c7e857e'
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
