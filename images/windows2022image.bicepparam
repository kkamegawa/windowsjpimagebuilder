using './windows2022image.bicep'

// Parameters for Windows Server 2022 image build
// Adjust repoBranch to a commit SHA for immutable builds if desired.
param repoBranch = 'Windows2022jp'

// Script integrity hashes (leave as '' to skip AIB checksum validation for a script)
param initScriptChecksum = '7148640BCCBC7B0A99975CBC006C1087F13BC31106B9ABFE21FA8A301E7ED552'
param installJpLangPackChecksum = 'A590BC9AD1317D0DF92A0F028CCECB1C7695AD473C66F1D67E6752D21C123890'
param configureLangChecksum = '4F31472CDE5AD434B03C9AF05418C235FB6959470273829817D2A913D15E12ED'
param finalizeScriptChecksum = 'A4D93AFB23F72FAFA8B13285CF56C31975E62A39BB536EC80A4AB6E23B620E32'

// Optional: override gallery image name or timeout etc. (uncomment & adjust as needed)
// param gallaryImageName = 'sigMyRGws2022'
// param imageTemplateName = 'imageTemplateMyRGws2022'
// param buildMaxTimeout = 240
// param vmSize = 'Standard_D4_v4'
