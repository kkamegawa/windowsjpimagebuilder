$subscriptionId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
$resourceGroupName ='CommunityPublic'
$aibName = "aib-communityimagecreator"
$imageRoleDefName = "Azure Image Builder Service Image Creation"

$aibjson = Get-Content RBACAzureImageBuilder.json -Raw
$aibjson = $aibjson.Replace('<subscriptionID>', $subscriptionId)
$aibjson = $aibjson.Replace('<resourceGroup>', $resourceGroupName)
$aibrbacfileName = Join-Path $env:TEMP 'aibRbac.json'
Set-Content -Path $aibrbacfileName -Value $aibjson -Force

New-AzRoleDefinition -InputFile $aibrbacfileName

New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $aibName -Location "Japan East"
$identityNameResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $aibName).Id
$identityNamePrincipalId = (Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $aibName).PrincipalId

$RoleAssignParams = @{
    ObjectId = $identityNamePrincipalId
    RoleDefinitionName = $imageRoleDefName
    Scope = "/subscriptions/$subscriptionID/resourceGroups/$resourceGroupName"
  }
New-AzRoleAssignment @RoleAssignParams

