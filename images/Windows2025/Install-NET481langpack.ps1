function Install-Binary
{
    <#
    .SYNOPSIS
        A helper function to install executables.

    .DESCRIPTION
        Download and install .exe or .msi binaries from specified URL.

    .PARAMETER Url
        The URL from which the binary will be downloaded. Required parameter.

    .PARAMETER Name
        The Name with which binary will be downloaded. Required parameter.

    .PARAMETER ArgumentList
        The list of arguments that will be passed to the installer. Required for .exe binaries.

    .EXAMPLE
        Install-Binary -Url "https://go.microsoft.com/fwlink/p/?linkid=2083338" -Name "winsdksetup.exe" -ArgumentList ("/features", "+", "/quiet")
    #>

    Param
    (
        [Parameter(Mandatory, ParameterSetName="Url")]
        [String] $Url,
        [Parameter(Mandatory, ParameterSetName="Url")]
        [String] $Name,
        [Parameter(Mandatory, ParameterSetName="LocalPath")]
        [String] $FilePath,
        [String[]] $ArgumentList
    )

    if ($PSCmdlet.ParameterSetName -eq "LocalPath")
    {
        $name = Split-Path -Path $FilePath -Leaf
    }
    else
    {
        Write-Host "Downloading $Name..."
        $filePath = Start-DownloadWithRetry -Url $Url -Name $Name
    }

    # MSI binaries should be installed via msiexec.exe
    $fileExtension = ([System.IO.Path]::GetExtension($Name)).Replace(".", "")
    if ($fileExtension -eq "msi")
    {
        if (-not $ArgumentList)
        {
            $ArgumentList = ('/i', $filePath, '/QN', '/norestart')
        }
        $filePath = "msiexec.exe"
    }

    try
    {
        $installStartTime = Get-Date
        Write-Host "Starting Install $Name..."
        $process = Start-Process -FilePath $filePath -ArgumentList $ArgumentList -Wait -PassThru
        $exitCode = $process.ExitCode
        $installCompleteTime = [math]::Round(($(Get-Date) - $installStartTime).TotalSeconds, 2)
        if ($exitCode -eq 0 -or $exitCode -eq 3010)
        {
            Write-Host "Installation successful in $installCompleteTime seconds"
        }
        else
        {
            Write-Host "Non zero exit code returned by the installation process: $exitCode"
            Write-Host "Total time elapsed: $installCompleteTime seconds"
            exit $exitCode
        }
    }
    catch
    {
        $installCompleteTime = [math]::Round(($(Get-Date) - $installStartTime).TotalSeconds, 2)
        Write-Host "Failed to install the $fileExtension ${Name}: $($_.Exception.Message)"
        Write-Host "Installation failed after $installCompleteTime seconds"
        exit 1
    }
}

function Start-DownloadWithRetry
{
    Param
    (
        [Parameter(Mandatory)]
        [string] $Url,
        [string] $Name,
        [string] $DownloadPath = "${env:Temp}",
        [int] $Retries = 20
    )

    if ([String]::IsNullOrEmpty($Name)) {
        $Name = [IO.Path]::GetFileName($Url)
    }

    $filePath = Join-Path -Path $DownloadPath -ChildPath $Name
    $downloadStartTime = Get-Date

    # Default retry logic for the package.
    while ($Retries -gt 0)
    {
        try
        {
            $downloadAttemptStartTime = Get-Date
            Write-Host "Downloading package from: $Url to path $filePath ."
            (New-Object System.Net.WebClient).DownloadFile($Url, $filePath)
            break
        }
        catch
        {
            $failTime = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
            $attemptTime = [math]::Round(($(Get-Date) - $downloadAttemptStartTime).TotalSeconds, 2)
            Write-Host "There is an error encounterd after $attemptTime seconds during package downloading:`n $_"
            $Retries--

            if ($Retries -eq 0)
            {
                Write-Host "File can't be downloaded. Please try later or check that file exists by url: $Url"
                Write-Host "Total time elapsed $failTime"
                exit 1
            }

            Write-Host "Waiting 30 seconds before retrying. Retries left: $Retries"
            Start-Sleep -Seconds 30
        }
    }

    $downloadCompleteTime = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
    Write-Host "Package downloaded successfully in $downloadCompleteTime seconds"
    return $filePath
}

$installerJPName = "ndp481-x86-x64-allos-jpn.exe"
$installerJPUrl = "https://download.microsoft.com/download/a/f/9/af9410a7-31c7-4a77-a7e0-1cd2e3320b37/${installerJPName}"
$ArgumentList = ("Setup", "/passive", "/norestart")

Install-Binary -Url $installerJPUrl -Name $installerJPName -ArgumentList $ArgumentList

