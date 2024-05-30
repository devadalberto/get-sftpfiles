#Requires -Version 5
#Requires -Modules Posh-SSH, PSFramework

Param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    #IE: "c:\TMP\BatchRequests\UserlISTs.txt"
    [string]$File = $(throw "text file required."),
    [Parameter(
        Mandatory = $false,
        Position = 1,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    #IE: "d:\sftp\gazimages\products"
    [string]$PathForDownloads
)

$modules = @("Posh-SSH", "PSFramework")

$modules | ForEach-Object { 
    $isInstalled = Get-Module -ListAvailable -Name $PSItem
    if (-not $isInstalled) {
        Install-Module -Name $PSItem -AllowClobber -AcceptLicense -SkipPublisherCheck 
    }
    Import-Module -Name $PSItem
}

#region get environment variables

# check if the file exists, if not create it and break
$envFilePath = "$($PSScriptRoot)\.env"
if (-not (Test-Path $envFilePath)) {
    New-Item -ItemType File -Path $envFilePath -Value $(Get-Content "$($envFilePath).sample")
    "Update values on $envFilePath file and re-run the script"
    exit
}

Get-Content $envFilePath | ForEach-Object {
    $name, $value = $PSItem.Split('=')
    Set-Content env:\$name $value
}
#endregion

$PathForDownloads = $env:PATH_4_DOWNLOAD
if (-not $PathForDownloads) {
    $downloadFolderName = "ftpTempFolder"
    $localDirectory = "$env:TEMP\$downloadFolderName"
}
else {
    $localDirectory = "$($PathForDownloads)\$env:STORAGE_ACCT"
}
if (-not (Test-Path $localDirectory)) {
    New-Item -ItemType Directory -Path $localDirectory
}

# 
$securePassword = ConvertTo-SecureString $sftpPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($sftpUsername, $securePassword)

# Create a new SFTP session
$sftpSession = New-SFTPSession -ComputerName $sftpServer -Port $sftpPort -Credential $Credential

# # List files in the remote directory
# $remoteFiles = Get-SFTPChildItem -SFTPSession $sftpSession -Path "/"

# $dateStamp = Get-Date -Format FileDateTimeUniversal
# $remoteFiles | Export-Csv -NoClobber -Path "./gazimages.products.$dateStamp.csv"
# # =========================================================================

# Create a list of the files to download
$filesToDownload = [System.Collections.Generic.List[object]]::new()

# process the text file
$txt = Get-Content $File
foreach ($line in $txt) {
    if ($line -ne "" -and $line[0] -ne "#" -and $line.ToLower() -ne "name") {
        $filesToDownload.Add($line)
    }
}

#region Download Files
$filesToDownload | ForEach-Object {
    $getParams = @{
        SFTPSession = $sftpSession
        Path        = $PSItem
        Destination = $localDirectory
        Force       = $true
        Verbose     = $true
    }
    Get-SFTPItem @getParams
}

#endregion Download Files

# Close the SFTP session
Remove-SFTPSession -SFTPSession $sftpSession