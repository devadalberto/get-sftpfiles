#Requires -Version 5
#Requires -Modules Posh-SSH, PSFramework
[CmdletBinding()]
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
    #IE: "d:\sftp\downloads\path"
    [string]$PathForDownloads
)
# measuring execution time
$stopWatch = [Diagnostics.Stopwatch]::StartNew()

#region Setting up the logging
$dateStampLog = Get-Date -Format FileDateUniversal
$logName = $MyInvocation.MyCommand.Name.Replace('.ps1', '')
$logPath = "$($PSScriptRoot)\logs"
$logFile = "{0}\$logName.$dateStampLog.log" -f $logPath

if (-not (Test-Path $logFile)) {
    New-Item -ItemType File -Path $logFile -ErrorAction SilentlyContinue -Force
    "Created Directory $logFile"
}


$paramSetPSFLoggingProvider = @{
    Name         = 'logfile'
    InstanceName = $logName
    FilePath     = $logFile
    FileType     = 'CMTrace'
    Enabled      = $true
    # Wait         = $true
}
#endregion Setting up the logging



$modules = @("Posh-SSH", "PSFramework")

#region Modules
# check if module is installed - install if not
$modules | ForEach-Object { 
    $isInstalled = Get-Module -ListAvailable -Name $PSItem
    if (-not $isInstalled) {
        try {
            Install-Module -Name $PSItem -AllowClobber -AcceptLicense -SkipPublisherCheck
            "Successfully Installed Module:`t$($PSItem)"
        }
        catch {
            "Error while installing Module:`t$($PSItem)`nExiting Script"
            Exit
        }
    }
}

# import PS modules
Set-PSFLoggingProvider @paramSetPSFLoggingProvider
Write-PSFMessage -Level SomewhatVerbose -Message "Initializing Log"
$modules | ForEach-Object { 
    try {
        Import-Module -Name $PSItem
        Write-PSFMessage -Level SomewhatVerbose -Message "Successfully Imported Module:`t$($PSItem)"
    }
    catch {
        Write-PSFMessage -Level Error -Message "Error while installing Module:`t$($PSItem)`nExiting Script"
        Exit
    }
}
#endregion Modules


#region get environment variables
# check if the file exists, if not create it and break
$envFilePath = "$($PSScriptRoot)\.env"
if (-not (Test-Path $envFilePath)) {
    New-Item -ItemType File -Path $envFilePath -Value $(Get-Content "$($envFilePath).sample")
    "Update values on $envFilePath file and re-run the script"
    Write-PSFMessage -Level Error -Message "Make sure to update .env file`nExiting Script"
    Exit
}

#testing
"Environment Variables: `n"
"==========================="

Get-Content $envFilePath | ForEach-Object {
    $name, $value = $PSItem.Split('=')
    try {
        Set-Content env:\$name $value
        Write-PSFMessage -Level SomewhatVerbose -Message "env:$name`tSuccessfully set."
    }
    catch {
        Write-PSFMessage -Level Error -Message "Error while setting env:$name`nExiting Script"
        Exit
    }
}
#endregion

$PathForDownloads = $env:PATH_4_DOWNLOAD
if (-not $PathForDownloads) {
    $downloadFolderName = "ftpTempFolder"
    $localDirectory = "$env:TEMP\$downloadFolderName"
    Write-PSFMessage -Level Warning -Message "Could not found a Path, saving files to: $localDirectory"
}
else {
    $localDirectory = "$($PathForDownloads)\$env:STORAGE_ACCT"
    Write-PSFMessage -Level SomewhatVerbose -Message "Found Path: $localDirectory"
}
if (-not (Test-Path $localDirectory)) {
    New-Item -ItemType Directory -Path $localDirectory
    Write-PSFMessage -Level Warning -Message "Created Directory`: $localDirectory"
}

#region SFTP session 
$sftpServer = $env:SFTPSERVER
$sftpPort = $env:SFTPPORT
$sftpUsername = $env:SFTPUSERNAME
$securePassword = ConvertTo-SecureString $env:SFTPPASSWORD -AsPlainText -Force

$Credential = New-Object System.Management.Automation.PSCredential ($sftpUsername, $securePassword)
# Create a new SFTP session
$sftpSession = New-SFTPSession -ComputerName $sftpServer -Port $sftpPort -Credential $Credential
if (-not $sftpSession) {
    Write-PSFMessage -Level Error -Message "SFTP session could not be created`n$($PSItem)"
}
Write-PSFMessage -Level SomewhatVerbose -Message "SFTP Session Established with:`t$sftpServer"

#endregion


#region Download Files
$filesToDownload = [System.Collections.Generic.List[object]]::new()

$txt = Get-Content $File
foreach ($line in $txt) {
    if ($line -ne "" -and $line[0] -ne "#" -and $line.ToLower() -ne "name") {
        $filesToDownload.Add($line)
    }
}

$getParams = @{
    SFTPSession = $sftpSession
    Path        = ''
    Destination = $localDirectory
    Force       = $true
    Verbose     = $true
}

$filesToDownload | ForEach-Object {
    $getParams['Path'] = $PSItem
    try {
        Get-SFTPItem @getParams
        Write-PSFMessage -Level Important -Message "File:`t$($PSItem)`t downloaded successfully to $localDirectory"
    }
    catch {
        Write-PSFMessage -Level Error -Message "Error while getting file.`n$($PSItem)"
    }
}

#endregion Download Files

# Close the SFTP session
Remove-SFTPSession -SFTPSession $sftpSession
Write-PSFMessage -Level Warning -Message "Closing Session:`t$sftpSession"

#region End Script
$stopWatch.Stop()
$elapsedTimeSeconds = ($stopWatch.ElapsedMilliseconds) / 1000
Write-PSFMessage -Level SomewhatVerbose -Message "Script ran in $("{0:N2}" -f $elapsedTimeSeconds)s."
#endregion End Script