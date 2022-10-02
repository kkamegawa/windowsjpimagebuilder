param location string = resourceGroup().location
param eulaUri string = 'https://aka.ms/azuresentinelcsp'
param galleryName string = 'sig${resourceGroup().name}'
param galleryImageName string = 'sigimg${resourceGroup().name}'
param recommendedMinvCPU int = 2
param recommendedMaxvCPU int = 16
param recommendedMinMemory int = 8
param recommendedMaxMemory int = 64
param publicPrefix string = 'public'
param publisherContact string = 'yourmail@exsample.com'
param imageOffer string = 'Windows2019Standard'
param imageSku string = 'jajp'
param imagePublisher string = 'YourName'

resource sharedImageResource 'Microsoft.Compute/galleries@2022-01-03' = {
  name: galleryName
  location: location
  tags: {
  }
  properties: {
    description: ''
    identifier: {}
    sharingProfile: {
      communityGalleryInfo: {
        eula: eulaUri
        publicNamePrefix: publicPrefix
        publisherContact: publisherContact
        publisherUri: eulaUri
      }
      permissions: 'Community'
    }
  }
}

resource ws2019Images 'Microsoft.Compute/galleries/images@2022-01-03' = {
  name: galleryImageName
  location: location
  tags: {
  }
  parent: sharedImageResource
  properties: {
    architecture: 'x64'
    description: ''
    disallowed: {
      diskTypes: [
      ]
    }
    endOfLifeDate: ''
    eula: eulaUri
    features: [
    ]
    hyperVGeneration: 'v1'
    identifier: {
      offer: imageOffer
      publisher: imagePublisher
      sku: imageSku
    }
    osState: 'Generalized'
    osType: 'Windows'
    privacyStatementUri: 'string'
    recommended: {
      memory: {
        max: recommendedMaxMemory
        min: recommendedMinMemory
      }
      vCPUs: {
        max: recommendedMaxvCPU
        min: recommendedMinvCPU
      }
    }
    releaseNoteUri: eulaUri
  }
}
