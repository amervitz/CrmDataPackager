Set-StrictMode -Version Latest

<#
.Synopsis
   Packs a folder extracted with Expand-CrmData into a Configuration Migration tool data .zip file.
.Description
   See https://github.com/amervitz/CrmDataPackager/blob/release/v3.0.0/docs/functions/Compress-CrmData.md
#>
function Compress-CrmData {
    param (
        # The folder path of an unpacked Configuation Migration tool generated zip file.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Folder,

        # The zip file to create after packing the configuration data files.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ZipFile
    )
    process
    {
        $logger = CreateLogger
        $sourcePath = Force-Resolve-Path $Folder
        $targetPath = Force-Resolve-Path $ZipFile
        $crmDataFolder = [CrmDataPackager.CrmDataFolder]::new($sourcePath, $logger)
        $crmDataFolder.Pack($targetPath) | Out-Null
    }
}

<#
.Synopsis
   Extracts a Configuration Migration tool data .zip file and decomposes the contents into separate files and folders.
.Description
   See https://github.com/amervitz/CrmDataPackager/blob/release/v3.0.0/docs/functions/Expand-CrmData.md
#>
function Expand-CrmData {
    param (
        # The path and filename to the Configuration Migration tool generated zip file.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName=$true)]
        [string]$ZipFile,

        # The folder path to store the unpacked records.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName=$true)]
        [string]$Folder,

        # The CrmDataPackager JSON settings file path for specifying per entity unpacking settings.
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$SettingsFile
    )
    process
    {      
        if(-not $SettingsFile) {
            $settingsFilePath = Join-Path -Path $PSScriptRoot -ChildPath settings.json
        } else {
            $settingsFilePath = Resolve-Path -Path $SettingsFile
        }

        $logger = CreateLogger
        $sourcePath = Force-Resolve-Path $ZipFile
        $targetPath = Force-Resolve-Path $Folder
        $crmDataFile = [CrmDataPackager.CrmDataFile]::new($sourcePath, $logger)
        $crmDataFile.Extract($targetPath, $settingsFilePath) | Out-Null
    }
}

function CreateLogger {
    $logger = [CrmDataPackager.PowerShellLogger]::new()
    $logger.TraceLogger = {
        param(
            [string]$message
        )
    
        Write-Verbose $message
    }
    $logger.DebugLogger = {
        param(
            [string]$message
        )
    
        $revert = $false

        if ($DebugPreference -eq 'Inquire') {
            $DebugPreference = 'Continue'
            $revert = $true
        }

        Write-Debug $message

        if($revert){
            $DebugPreference = 'Inquire'
        }
    }
    $logger.ErrorLogger = {
        param(
            [string]$message
        )
    
        Write-Error $message
    }
    $logger.InformationLogger = {
        param(
            [string]$message
        )
    
        Write-Information $message
    }
    return $logger
}

# https://stackoverflow.com/a/12605755/4797690
function Force-Resolve-Path {
    <#
    .SYNOPSIS
        Calls Resolve-Path but works for files that don't exist.
    .REMARKS
        From http://devhawk.net/blog/2010/1/22/fixing-powershells-busted-resolve-path-cmdlet
    #>
    param (
        [string] $FileName
    )

    $FileName = Resolve-Path $FileName -ErrorAction SilentlyContinue `
                                       -ErrorVariable _frperror
    if (-not($FileName)) {
        $FileName = $_frperror[0].TargetObject
    }

    return $FileName
}
