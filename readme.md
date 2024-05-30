# get-sftpfiles

## Pre-requisites

1. Access to the PSGallery
2. Update the password in the **get-sftpfiles.ps1** file REPLACE_THIS
3. File with a list of the files to be copied/downloaded
   1. 1 name per line
   2. File must have the extension: '.txt'


## How to run this script:

Below command will run and download the the files to the OS TEMP folder under 'ftpTempFolder'

```powershell
.\get-sftpfiles.ps1 -File .\samplefile.txt
```

Optionally, you can (and should) specify the download directory

```powershell
.\get-sftpfiles.ps1 -File .\samplefile.txt -PathForDownloads 'F:\ftptest'
```

## ToDo's

- [ ] Add logging (will be done later today)
- [ ] Should the password be passed as a parameter or environment variable (or keep it as is )
- [ ] Input file extension (txt) works?
- [ ] Directory location (path) for the downloaded files needs to be updated (currently set to C:\Users\USERNAME\AppData\Local\Temp\ftpTempFolder)
