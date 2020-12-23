Set-StrictMode -Version Latest

<#
.Synopsis
   Packs and zips a folder of Configuration Migration tool generated files previously created from the Expand-CrmData cmdlet.
.DESCRIPTION
   This function packs and zips the folders and files created from Expand-CrmData processing of a Configuration Migration tool generated zip file.
.EXAMPLE
   Compress-CrmData -Folder 'C:\temp\data\AdventureWorks' -ZipFile 'C:\temp\packed\AdventureWorksData.zip'

   This example processes the contents of the specified -Folder with an already exported data set from an AdventureWorks organization and saves the packed zip file to the specified -ZipFile.
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

    CrmConfigurationPackager -Pack -Path $Folder -DestinationPath $ZipFile
}

<#
.Synopsis
   Extracts and unpacks a Configuration Migration tool generated zip file to individual files.
.DESCRIPTION
   This function extracts a Configuration Migration tool generated zip file and unpacks the .xml files into separate files and folders, where each entity is stored in its own folder and each record is stored in its own .xml file inside the entity folder.
.EXAMPLE
   Expand-CrmData -ZipFile 'C:\temp\export\AdventureWorksData.zip' -Folder 'C:\temp\data\AdventureWorks'

   This example extracts the data zip file exported from the AdventureWorks organization and unpacks the contents to the specified -Folder.
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
        CrmConfigurationPackager -Extract -Path $ZipFile -DestinationPath $Folder -SettingsFile $SettingsFile
    }
}

function Format-Xml {
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [xml]$Xml,

        [Parameter()]
        [int]$Indent=2
    )

    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.Xml.XmlTextWriter $StringWriter
    $XmlWriter.Formatting = "indented"
    $XmlWriter.Indentation = $Indent
    $Xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}

function CreateRootSchema {
    param (
        [Parameter(Mandatory=$true)]
        [xml]$xml,

        [Parameter(Mandatory=$true)]
        [string]$DataPath

    )

    [xml]$rootSchema = $xml.CloneNode($true)

    foreach($entity in $rootSchema.entities.entity) {
        $entityFolder = Get-Item (Join-Path $DataPath $entity.name) -ErrorAction Ignore

        if($entityFolder) {

            # remove extraneous attributes that aren't helpful when viewing the file
            $removeAttributes = $entity.Attributes | Where-Object {$_.name -notin ('name','displayName')}
            foreach ($remove in $removeAttributes){
                $entity.RemoveAttribute($remove.name)
            }

            # remove child elements and make the entity element self-closing tag
            $entity.IsEmpty = $true

        } else {
            Write-Verbose "Removing $($entity.name) from root schema file due to no data for entity"
            $rootSchema.entities.RemoveChild($entity) | Out-Null
        }
    }

    return $rootSchema
}

function ExtractData {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,

        [Parameter()]
        $settings
    )

    Write-Verbose "Loading assembly System.Web"
    Add-Type -AssemblyName System.Web

    Write-Verbose "Loading assembly Newtonsoft.Json"
    Add-Type -Path (Join-Path -Path $PSScriptRoot -ChildPath Newtonsoft.Json.dll)

    [xml]$xml = Get-Content -Path $Path -Encoding UTF8

    foreach($entity in $xml.entities.entity) {
        $entityFolder = New-Item -ItemType Directory -Path (Join-Path -Path $DestinationPath -ChildPath $entity.name)
        $recordsFolder = New-Item -ItemType Directory -Path (Join-Path -Path $entityFolder -ChildPath records)

        $settingEntity = $settings.entities | Where-Object {$_.entity -eq $entity.name}

        foreach($record in $entity.records.record) {
            if($settingEntity) {
                foreach($field in $settingEntity.fields) {
                    WriteFileAndUpdateRecord -Entity $entity -RecordsFolder $recordsFolder -Record $record -EntityName $settingEntity.entity -FieldName $field.field -FileExtension $field.extension -Format:$field.format
                }
            }

            $recordPath = Join-Path -Path $recordsFolder -ChildPath "$($record.id).xml"

            Write-Verbose "Writing file $recordPath"
            Set-Content -Path $recordPath -Value (Format-Xml -xml $record.OuterXml) -Encoding UTF8
        }      

        if($entity.m2mrelationships.GetType() -eq [System.Xml.XmlElement]) {
            $m2mrelationshipsPath = Join-Path -Path $entityFolder -ChildPath m2mrelationships
            Write-Verbose "Creating folder $m2mrelationshipsPath"
            $m2mrelationshipsFolder = New-Item -ItemType Directory -Path $m2mrelationshipsPath

            foreach($m2mrelationship in $entity.m2mrelationships.m2mrelationship) {
                $m2mrelationshipnamePath = Join-Path -Path $m2mrelationshipsFolder -ChildPath $m2mrelationship.m2mrelationshipname
                $m2mrelationshipnameFolder = Get-Item -Path $m2mrelationshipnamePath -ErrorAction Ignore
                if($m2mrelationshipnameFolder -eq $null) {
                    Write-Verbose "Creating folder $m2mrelationshipnamePath"
                    $m2mrelationshipnameFolder = New-Item -ItemType Directory -Path $m2mrelationshipnamePath -ErrorAction Ignore
                }
                $m2mrelationshipPath = Join-Path $m2mrelationshipnameFolder -ChildPath "$($m2mrelationship.sourceid).xml"
                Write-Verbose "Writing file $m2mrelationshipPath"
                Set-Content -Path $m2mrelationshipPath -Value (Format-Xml -Xml $m2mrelationship.OuterXml) -Encoding UTF8
            }
        }
    }

    $rootData = CreateRootSchema -xml $xml -DataPath $DestinationPath

    # write back the condensed version of the data.xml file to the root of the folder
    Set-Content -Path (Join-Path -Path $DestinationPath -ChildPath 'data.xml') -Value (Format-Xml -xml $rootData.OuterXml) -Encoding UTF8
}

function CreateManifest {
    param(
        $Path,

        $Settings
    )

    $manifest = [ordered]@{
        version = $MyInvocation.MyCommand.Module.Version.ToString()
        timestamp = [DateTime]::UtcNow.ToString("o")
        entities = $Settings.entities
    }

    $json = ConvertTo-Json $manifest -Depth 5

    $formatted = [Newtonsoft.Json.Linq.JToken]::Parse($json).ToString()

    $settingsPath = Join-Path -Path $Path -ChildPath settings.json
    Write-Verbose "Writing file $settingsPath"
    Set-Content -Value $formatted -Path $settingsPath -Encoding UTF8
}

function WriteFileAndUpdateRecord {
    param (
        [Parameter(Mandatory=$true)]
        $Entity,

        [Parameter(Mandatory=$true)]
        $RecordsFolder,

        [Parameter(Mandatory=$true)]
        $Record,

        [Parameter(Mandatory=$true)]
        [string]$EntityName,

        [Parameter(Mandatory=$true)]
        [string]$FieldName,

        [Parameter(Mandatory=$true)]
        [string]$FileExtension,

        [switch]$Format
    )

    $field = $Record.field | Where-Object {$_.name -eq $FieldName}
    if($field) {

        if($EntityName -eq 'annotation' -and $FieldName -eq 'documentbody' -and $FileExtension -eq 'auto') {
            # unpack the documentbody field from annotations, by converting it from base 64 encoding and saving to the file system
            $filenamefield = $record.field | Where-Object {$_.name -eq 'filename'}
            $documentbody = [Convert]::FromBase64String($field.value)
            $fileextension = [IO.Path]::GetExtension($filenamefield.value)
            $documentbodyfilename = "$($record.id)$fileextension"
            $documentbodyFolder = Join-Path -Path $recordsFolder -ChildPath 'documentbody'
            $documentbodyPath = Join-Path -Path $documentbodyFolder -ChildPath $documentbodyfilename
            New-Item -ItemType Directory -Path $documentbodyFolder -ErrorAction SilentlyContinue | Out-Null
            Write-Verbose "Writing file $documentbodyPath"
            [IO.File]::WriteAllBytes($documentbodyPath, $documentbody)

            # set the documentbody field value to the generated unpacked filename so the base 64 encoded text isn't written to disk and the file can be easily identified
            $path = [string](Join-Path -Path 'documentbody' -ChildPath $documentbodyfilename)
            $md5 = GetBytesHashMD5 -Bytes $documentbody
            $fileId = CreateFileId -Path $path -MD5 $md5
            $field.SetAttribute("value", $fileId)
        } else {
            if($EntityName -eq 'adx_contentsnippet' -and $FieldName -eq 'adx_value' -and $FileExtension -eq 'auto') {
                # determine if the type is text or html, set the file extension accordingly
                $type = $record.field | Where-Object {$_.name -eq 'adx_type'}
                $FileExtension = ".txt"
                if($type -and $type.value -eq "756150001") {
                    $FileExtension = ".html"
                }
            }

            $fileId = WriteTextFile -RecordsFolder $RecordsFolder -Record $Record -Field $field -FileExtension $FileExtension -Format:$Format

            # set the field value to the unpacked filename and hash so the original text isn't written to disk and the file can be easily identified
            $field.SetAttribute("value", $fileId)
        }
    }
}

function WriteTextFile {
    param (
        $RecordsFolder,

        [Parameter(Mandatory=$true)]
        $Record,

        [Parameter(Mandatory=$true)]
        $Field,

        [Parameter()]
        [string]$FileExtension,

        [switch]$Format
    )
    
    $value = [System.Web.HttpUtility]::HtmlDecode($Field.value)

    if($FileExtension -eq '.json' -and $Format) {
        $value = [Newtonsoft.Json.Linq.JToken]::Parse($value).ToString()
    }

    $filename = "$($record.id)$($FileExtension)"
    $folder = Join-Path -Path $RecordsFolder -ChildPath $Field.name
    $path = Join-Path -Path $folder -ChildPath $filename

    New-Item -ItemType Directory -Path $folder -ErrorAction SilentlyContinue | Out-Null
    Write-Verbose "Writing file $path"
    Set-Content -Path $path -Value $value -Encoding UTF8 -NoNewline

    # save the relative path to the new file so it can be easily identified in the original record
    $relativePath = [string](Join-Path -Path $Field.name -ChildPath $filename)

    # save the hash so changes can be identified in the original record
    $hash = GetTextHashMD5 -Text $value

    return CreateFileId -Path $relativePath -MD5 $hash
}

function GetTextHashMD5 {
    param (
        [string]$Text
    )

    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($Text))
    $hash = Get-FileHash -InputStream $stream -Algorithm MD5
    return $hash.Hash
}

function GetBytesHashMD5 {
    param (
        [byte[]]$Bytes
    )

    $stream = [System.IO.MemoryStream]::new($Bytes)
    $hash = Get-FileHash -InputStream $stream -Algorithm MD5
    return $hash.Hash
}

function CreateFileId {
    param (
        [string]$Path,

        [string]$MD5
    )
    
    return "$path,$md5"
}


function PackData {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    $settingsFile = Join-Path -Path $Path -ChildPath settings.json
    
    if((Test-Path -Path $settingsFile) -eq $false) {
        $settingsFile = Join-Path -Path $PSScriptRoot -ChildPath settings.json
    }

    Write-Verbose "Loading file $settingsFile"
    $settings = ConvertFrom-Json (Get-Content -Raw -Path $SettingsFile)

    Write-Verbose "Loading assembly System.Web"
    Add-Type -AssemblyName System.Web

    Write-Verbose "Loading assembly Newtonsoft.Json"
    Add-Type -Path (Join-Path -Path $PSScriptRoot -ChildPath Newtonsoft.Json.dll)

    $rootDataPath = Join-Path -Path $Path -ChildPath data.xml

    Write-Verbose "Loading file $rootDataPath"
    [xml]$xml = Get-Content -Path $rootDataPath -Encoding UTF8

    foreach($entity in $xml.entities.entity) {
        $entityFolder = Get-Item -Path (Join-Path -Path $Path -ChildPath $entity.name) -ErrorAction Ignore

        if($entityFolder -eq $null) {
            Write-Verbose "No data for entity $($entity.name), skipping data pack"
            $xml.entities.RemoveChild($entity) | Out-Null
            continue
        }

        $recordsFolder = Get-Item -Path (Join-Path -Path $entityFolder -ChildPath 'records')

        # load all the xml files that represent each CRM record
        $recordFiles = Get-ChildItem -Path $recordsFolder -Filter '*.xml'

        # create the stub records element where each CRM record will be stored
        $recordsNode = $xml.ImportNode(([xml]"<records />").DocumentElement, $true)

        $entity.AppendChild($recordsNode) | Out-Null

        $settingEntity = $settings.entities | Where-Object {$_.entity -eq $entity.name}

        # read the record xml for each CRM record from disk, and add it to the records element
        foreach($recordFile in $recordFiles) {
            Write-Verbose "Loading file $($recordFile.FullName)"
            $recordData = [xml](Get-Content -Path $recordFile.FullName -Encoding UTF8)

            if($settingEntity) {
                foreach($field in $settingEntity.fields) {
                    LoadFileAndUpdateRecord -RecordsFolder $recordsFolder -Record $recordData.record -Entity $entity -EntityName $settingEntity.entity -FieldName $field.field -Extension $field.extension -Format:$field.format
                }
            }

            $recordDataNode = $xml.ImportNode($recordData.DocumentElement, $true)
            $recordsNode.AppendChild($recordDataNode) | Out-Null
        }

        # create the stub m2mrelationships element that will be replaced with the m2mrelationships.xml file
        $m2mStubNode = $xml.ImportNode(([xml]"<m2mrelationships />").DocumentElement, $true)
        $entity.AppendChild($m2mStubNode)| Out-Null

        # try load the m2mrelationships, if it exists, replace the m2mrelationships node
        $m2mrelationshipsFilePath = Join-Path -Path $entityFolder -ChildPath m2mrelationships.xml
        $m2mrelationshipsFolderPath = Join-Path -Path $entityFolder -ChildPath m2mrelationships

        if(Test-Path -Path $m2mrelationshipsFilePath -PathType Leaf) {
            Write-Verbose "Loading file $m2mrelationshipsFilePath"
            $m2mData = [xml](Get-Content -Path $m2mrelationshipsFilePath -Encoding UTF8)
            $m2mNode = $xml.ImportNode($m2mData.DocumentElement, $true)
            $entity.ReplaceChild($m2mNode, $m2mStubNode) | Out-Null
        } elseif(Test-Path -Path $m2mrelationshipsFolderPath -PathType Container) {
            $m2mrelationshipsFolders = Get-ChildItem -Path $m2mrelationshipsFolderPath

            foreach($m2mrelationshipFolder in $m2mrelationshipsFolders) {
                $m2mrelationshipFiles = Get-ChildItem -Path $m2mrelationshipFolder.FullName -Filter '*.xml'

                foreach($m2mrelationshipFile in $m2mrelationshipFiles) {
                    Write-Verbose "Loading file $($m2mrelationshipFile.FullName)"
                    $m2mrelationshipData = [xml](Get-Content -Path $m2mrelationshipFile.FullName -Encoding UTF8)
                    $m2mrelationshipDataNode = $xml.ImportNode($m2mrelationshipData.DocumentElement, $true)
                    $m2mStubNode.AppendChild($m2mrelationshipDataNode) | Out-Null
                }
            }
        }
    }

    # write the packed version of the data.xml file to the root of the folder
    $dataOutPath = Join-Path -Path $DestinationPath -ChildPath 'data.xml'
    Write-Verbose "Writing file $dataOutPath"
    Set-Content -Path $dataOutPath -Value (Format-Xml -xml $xml.OuterXml) -Encoding UTF8
}

function LoadFileAndUpdateRecord {
    param (
        [Parameter(Mandatory=$true)]
        $RecordsFolder,

        [Parameter(Mandatory=$true)]
        $Record,

        [Parameter(Mandatory=$true)]
        $Entity,

        [Parameter(Mandatory=$true)]
        [string]$EntityName,

        [Parameter(Mandatory=$true)]
        [string]$FieldName,

        [string]$Extension,

        [switch]$Format
    )

    if($EntityName -eq 'annotation' -and $FieldName -eq 'documentbody' -and $Extension -eq 'auto') {
        # pack the documentbody field from annotations, by converting it from binary to base 64 encoding
        $documentbodyfield = $recordData.record.field | Where-Object {$_.name -eq 'documentbody'}

        if($documentbodyfield) {
            $relativePath = $documentbodyfield.value.Split(',')[0]
            $documentbodypath = Join-Path -Path $recordsFolder -ChildPath $relativePath
            Write-Verbose "Loading file $documentbodypath"
            $documentbodyBytes = Get-Content -Path $documentbodypath -Encoding Byte -Raw
            $documentbodybase64 = [Convert]::ToBase64String($documentbodyBytes)
            $documentbodyfield.value = $documentbodybase64
        }
    } else {
        $field = $record.field | Where-Object {$_.name -eq $FieldName}

        if($field -and $field.value.StartsWith($FieldName)) {
            $relativePath = $field.value.Split(',')[0]
            $filePath = Join-Path -Path $RecordsFolder -ChildPath $relativePath
            Write-Verbose "Loading file $filePath"

            $value = Get-Content -Path $filePath -Encoding UTF8 -Raw

            if($relativePath.EndsWith(".json") -and $Format) {
                $value = [Newtonsoft.Json.Linq.JToken]::Parse($value).ToString([Newtonsoft.Json.Formatting]::None)
            }

            $encoded = [System.Web.HttpUtility]::HtmlEncode($value)
            $field.SetAttribute("value", $encoded)
        }
    }
}

function ExtractSchema {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    $xml = [xml](Get-Content -Path $Path -Encoding UTF8)

    foreach($entity in $xml.entities.entity) {
        $entityFolder = Get-Item -Path (Join-Path -Path $DestinationPath -ChildPath $entity.name) -ErrorAction Ignore
        if($entityFolder) {
            $schemaPath = Join-Path -Path $entityFolder -ChildPath 'data_schema.xml'
            Write-Verbose "Writing file $schemaPath"
            Set-Content -Path $schemaPath -Value (Format-Xml -xml $entity.OuterXml) -Encoding UTF8
        } else {
            Write-Verbose "No data for entity $($entity.name), skipping schema extract"
        }
    }

    $rootSchema = CreateRootSchema -xml $xml -DataPath $DestinationPath

    Set-Content -Path (Join-Path -Path $DestinationPath -ChildPath 'data_schema.xml') -Value (Format-Xml -xml $rootSchema.OuterXml) -Encoding UTF8
}

function PackSchema {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    $rootSchemaPath = Join-Path -Path $Path -ChildPath data_schema.xml
    Write-Verbose "Loading file $rootSchemaPath"
    $xml = [xml](Get-Content -Path $rootSchemaPath -Encoding UTF8)

    foreach($entity in $xml.entities.entity) {
        $entityFolder = Get-Item -Path (Join-Path -Path $Path -ChildPath $entity.name) -ErrorAction Ignore
        if($entityFolder) {
            $schemaPath = Join-Path -Path $entityFolder -ChildPath 'data_schema.xml'
            Write-Verbose "Loading file $schemaPath"
            $entitySchema = [xml](Get-Content -Path $schemaPath -Encoding UTF8)
            $entitySchemaNode = $xml.ImportNode($entitySchema.DocumentElement, $true)
            $xml.entities.ReplaceChild($entitySchemaNode, $entity) | Out-Null
        } else {
            Write-Verbose "No data for entity $($entity.name), skipping schema pack"
            $xml.entities.RemoveChild($entity) | Out-Null
        }
    }

    if($SchemaOnly) {
        $outPath = $DestinationPath
    } else {
        # write the packed version of the data_schema.xml file to the root of the folder
        $outPath = Join-Path -Path $DestinationPath -ChildPath 'data_schema.xml'
    }

    Write-Verbose "Writing file $outPath"
    Set-Content -Path $outPath -Value (Format-Xml -xml $xml.OuterXml) -Encoding UTF8
}

function PackContentTypes {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    $sourceContentTypesPath = Join-Path -Path $Path -ChildPath "[Content_Types].xml"
    $destinationContentTypesPath = Join-Path -Path $DestinationPath -ChildPath "[Content_Types].xml"
    Write-Verbose "Writing file $destinationContentTypesPath"
    Copy-Item -LiteralPath $sourceContentTypesPath -Destination $destinationContentTypesPath
}

function CrmConfigurationPackager {
    param (
        [Parameter(Mandatory=$true,ParameterSetName="Extract")]
        [Switch]$Extract,

        [Parameter(Mandatory=$true,ParameterSetName="Pack")]
        [Switch]$Pack,

        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$SettingsFile,

        # convert the packed version of the data to a zip file
        [Parameter(ParameterSetName="Pack")]
        [switch]$Compress = $true,

        # only pack the schema
        [Parameter(ParameterSetName="Pack")]
        [switch]$SchemaOnly
    )

    if($Extract) {

        if(Get-Item -Path $DestinationPath -OutVariable DestinationFullPath -ErrorAction Ignore) {
            Write-Verbose "Deleting folder $DestinationPath"

            Remove-Item -Path $DestinationFullPath -Recurse -Force
        }

        if([IO.Path]::GetExtension($Path) -eq '.zip') {
            Expand-Archive -Path $Path -DestinationPath $DestinationPath
        } else {
            Copy-Item -Path $Path -Destination $DestinationPath -Recurse
        }

        $dataPath = Join-Path -Path $DestinationPath -ChildPath data.xml
        $schemaPath = Join-Path -Path $DestinationPath -ChildPath data_schema.xml

        if(-not $SettingsFile) {
            $SettingsFile = Join-Path -Path $PSScriptRoot -ChildPath settings.json
        }
    
        Write-Verbose "Loading file $SettingsFile"
        $settings = ConvertFrom-Json (Get-Content -Raw -Path $SettingsFile)

        ExtractData -Path $dataPath -DestinationPath $DestinationPath -Settings $settings
        ExtractSchema -Path $schemaPath -DestinationPath $DestinationPath
        CreateManifest -Path $DestinationPath -Settings $settings
    } elseif($Pack)  {

        # when target is a zip file, pack the contents to a temporary folder, then delete the temporary folder when done
        if([IO.Path]::GetExtension($DestinationPath) -eq '.zip') {
            $extractPath = Join-Path -Path ([IO.Path]::GetDirectoryName($DestinationPath)) -ChildPath (([IO.Path]::GetFileNameWithoutExtension(($DestinationPath)) + (Get-Date -Format '-yyyy-mm-dd-HHmmss')))
        } else {
            $extractPath = $DestinationPath
        }

        if(!$SchemaOnly -and !(Test-Path -Path $extractPath)) {
            Write-Verbose "Creating temporary folder $extractPath"
            New-Item -Path $extractPath -ItemType Directory | Out-Null
        }

        PackSchema -Path $Path -DestinationPath $extractPath

        if(!$SchemaOnly) {
            PackData -Path $Path -DestinationPath $extractPath
            PackContentTypes -Path $Path -DestinationPath $extractPath

            # when target is a zip file, create the zip file, then delete the temporary folder
            if([IO.Path]::GetExtension($DestinationPath) -eq '.zip') {
                Write-Verbose "Writing file $DestinationPath"
                Compress-Archive -Path (Join-Path $extractPath '*') -DestinationPath $DestinationPath -Force
                Write-Verbose "Deleting temporary folder $extractPath"
                Remove-Item -Path $extractPath -Recurse -Force
            }
        }
    }
}
