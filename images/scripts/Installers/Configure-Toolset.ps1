################################################################################
##  File:  Configure-Toolset.ps1
##  Team:  CI-Build
##  Desc:  Configure Toolset
################################################################################

Function Set-DefaultVariables
{
    param
    (
        [Parameter(Mandatory=$true)]
        [object] $EnvVars,
        [Parameter(Mandatory=$true)]
        [string] $ToolVersionPath
    )

    $templates = $EnvVars.pathTemplates
    foreach ($template in $templates)
    {
        $toolSystemPath = $template -f $ToolVersionPath
        Add-MachinePathItem -PathItem $toolSystemPath | Out-Null
    }

    if (-not ([string]::IsNullOrEmpty($EnvVars.defaultVariable)))
    {
        setx $toolEnvVars.defaultVariable $ToolVersionPath /M | Out-Null
    }
}

Invoke-PesterTests -TestFile "Toolset"
