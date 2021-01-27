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

        $settingsEntity = $settings.entities | Where-Object {$_.entity -eq $entity.name}

        $entitySettings = LoadEntitySettings -Entity $entity -SettingsEntity $settingsEntity

        foreach($record in $entity.records.record) {
            if($settingsEntity) {
                foreach($field in $settingsEntity.fields) {

                    $fieldSettings = LoadFieldSettings -SettingsField $field

                    if($fieldSettings.field) {
                        WriteFileAndUpdateRecord -Entity $entity -RecordsFolder $recordsFolder -Record $record -FieldSettings $fieldSettings
                    }
                }
            }

            $fileNamePrefix = $record.id
            $fileExtension = $entitySettings.extension
            $fileName = "$($fileNamePrefix)$($fileExtension)"
            
            if($entitySettings.fileNameField -ne "id") {
                $fileNamePrefix = GetFileNamePrefix -FileNameField $fieldSettings.fileNameField -Record $Record 
                $fileNamePrefix = EscapeFileName -FileName $fileNamePrefix
                $fileName = "$($fileNamePrefix)$($fileExtension)"

                $recordPath = Join-Path -Path $recordsFolder -ChildPath $fileName

                if(Test-Path -Path $recordPath) {
                    $existingFileName = $fileName
                    $fileName = "$($record.id)$($fileExtension)"

                    Write-Warning "Naming $($entity.name) file $fileName to avoid conflict with existing file $existingFileName"
                }
            }

            $recordPath = Join-Path -Path $recordsFolder -ChildPath $fileName

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
        [PSCustomObject]$FieldSettings
    )

    $field = $Record.field | Where-Object {$_.name -eq $FieldSettings.field}

    if($field) {

        if($Entity.name -eq 'annotation' -and $FieldSettings.field -eq 'documentbody' -and $FieldSettings.extension -eq 'auto') {

            $documentbodyFolder = Join-Path -Path $recordsFolder -ChildPath 'documentbody'
            New-Item -ItemType Directory -Path $documentbodyFolder -ErrorAction SilentlyContinue | Out-Null
            
            # unpack the documentbody field from annotations, by converting it from base 64 encoding and saving to the file system
            $annotationFileNameField = $record.field | Where-Object {$_.name -eq 'filename'}

            $documentbody = [Convert]::FromBase64String($field.value)
            
            if($FieldSettings.fileNameField -ne "id") {
                $documentbodyfilename = EscapeFileName -FileName $annotationFileNameField.value
                $documentbodyPath = Join-Path -Path $documentbodyFolder -ChildPath $documentbodyfilename

                if(Test-Path -Path $documentbodyPath) {
                    $existingFileName = $documentbodyfilename
                    $annotationFileExtension = [IO.Path]::GetExtension($annotationFileNameField.value)
                    $documentbodyfilename = "$($record.id)$annotationFileExtension"

                    Write-Warning "Naming $($Entity.name)\$($field.name) file $documentbodyfilename to avoid conflict with existing file $existingFileName"
                }
            } else {
                $annotationFileExtension = [IO.Path]::GetExtension($annotationFileNameField.value)
                $documentbodyfilename = "$($record.id)$annotationFileExtension"
            }

            $documentbodyPath = Join-Path -Path $documentbodyFolder -ChildPath $documentbodyfilename

            Write-Verbose "Writing file $documentbodyPath"
            [IO.File]::WriteAllBytes($documentbodyPath, $documentbody)

            # set the documentbody field value to the generated unpacked filename so the base 64 encoded text isn't written to disk and the file can be easily identified
            $Field.RemoveAttribute("value")
            $path = [string](Join-Path -Path 'documentbody' -ChildPath $documentbodyfilename)
            $field.SetAttribute("path", $path)
            
            if($FieldSettings.hash) {
                $md5 = GetBytesHashMD5 -Bytes $documentbody
                $field.SetAttribute("hash", $md5)
            }
        } else {
            if($Entity.name -eq 'adx_contentsnippet' -and $FieldSettings.field -eq 'adx_value' -and $FieldSettings.extension -eq 'auto') {
                # determine if the type is text or html, set the file extension accordingly
                $type = $record.field | Where-Object {$_.name -eq 'adx_type'}
                $FieldSettings.extension = ".txt"
                if($type -and $type.value -eq "756150001") {
                    $FieldSettings.extension = ".html"
                }
            }

            $fileInfo = WriteTextFile -EntityName $Entity.name -RecordsFolder $RecordsFolder -Record $Record -Field $field -FieldSettings $FieldSettings

            # set the field value to the unpacked filename and hash so the original text isn't written to disk and the file can be easily identified
            $field.RemoveAttribute("value")
            $field.SetAttribute("path", $fileInfo.path)

            if($FieldSettings.hash) {
                $field.SetAttribute("hash", $fileInfo.hash)
            }
        }
    }
}

function WriteTextFile {
    param (
        $EntityName,

        $RecordsFolder,

        [Parameter(Mandatory=$true)]
        $Record,

        [Parameter(Mandatory=$true)]
        $Field,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$FieldSettings
    )
    
    $value = [System.Web.HttpUtility]::HtmlDecode($Field.value)

    $fileNamePrefix = GetFileNamePrefix -FileNameField $FieldSettings.fileNameField -Record $Record 

    if($FieldSettings.fileNameField -ne "id") {
        $fileNamePrefix = EscapeFileName -FileName $fileNamePrefix
    }

    if($FieldSettings.extension -eq '.json' -and $FieldSettings.format) {
        $value = [Newtonsoft.Json.Linq.JToken]::Parse($value).ToString()
    }

    $fileName = "$($fileNamePrefix)$($FieldSettings.extension)"
    $folder = Join-Path -Path $RecordsFolder -ChildPath $Field.name
    $path = Join-Path -Path $folder -ChildPath $fileName

    if($FieldSettings.fileNameField -ne "id" -and (Test-Path -Path $path)) {
        $existingFileName = $fileName
        $fileName = "$($record.id)$($FieldSettings.extension)"
        $folder = Join-Path -Path $RecordsFolder -ChildPath $Field.name

        Write-Warning "Naming $EntityName\$($Field.name) file $fileName to avoid conflict with existing file $existingFileName"

        $path = Join-Path -Path $folder -ChildPath $fileName
    }

    New-Item -ItemType Directory -Path $folder -ErrorAction SilentlyContinue | Out-Null
    Write-Verbose "Writing file $path"
    Set-Content -Path $path -Value $value -Encoding UTF8 -NoNewline

    # save the relative path to the new file so it can be easily identified in the original record
    $relativePath = [string](Join-Path -Path $Field.name -ChildPath $fileName)

    # save the hash so changes can be identified in the original record
    if($FieldSettings.hash) {
        $hash = GetTextHashMD5 -Text $value

        return @{
            path = $relativePath
            hash = $hash
        }
    } else {
        return @{
            path = $relativePath
            hash = ''
        }
    }
}

function EscapeFileName {
    param (
        [Parameter(Mandatory=$true)]
        $FileName
    )

    $specialCharacters = '\', '/', ':', '*', '?', '"', '<', '>', '|', ` # windows reserved characters
                         ','                                            # field value reserved characters
    
    $fileNameChars = $FileName.ToCharArray()

    $fileNameSb = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $fileNameChars.Length; $i++) { 
        if($fileNameChars[$i] -cin $specialCharacters) {
            $fileNameSb.Append([uri]::EscapeDataString($fileNameChars[$i])) | Out-Null
        } else {
            $fileNameSb.Append($fileNameChars[$i]) | Out-Null
        }
    }

    $escaped = $fileNameSb.ToString()
    return $escaped
}

function GetFileNamePrefix {
    param (
        [Parameter(Mandatory=$true)]
        $Record,

        [Parameter()]
        [string]$FileNameField
    )
    
    if($FileNameField -eq 'id') {
        return $record.id
    }

    if($FileNameField) {
        $field = $record.field | Where-Object {$_.name -eq $FileNameField}
        if($field) {
            return $field.value
        }
    }

    return $record.id
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
        [string]$DestinationPath,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Settings
    )

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

        $settingsEntity = $settings.entities | Where-Object {$_.entity -eq $entity.name}

        $entitySettings = LoadEntitySettings -Entity $entity -SettingsEntity $settingsEntity

        # read the record xml for each CRM record from disk, and add it to the records element
        foreach($recordFile in $recordFiles) {
            Write-Verbose "Loading file $($recordFile.FullName)"
            $recordData = [xml](Get-Content -Path $recordFile.FullName -Encoding UTF8)

            if($settingsEntity) {
                foreach($field in $settingsEntity.fields) {
                    $fieldSettings = LoadFieldSettings -SettingsField $field

                    LoadFileAndUpdateRecord -RecordsFolder $recordsFolder -Record $recordData.record -Entity $entity -FieldSettings $fieldSettings
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
        $FieldSettings
    )

    if($Entity.name -eq 'annotation' -and $FieldSettings.field -eq 'documentbody' -and $FieldSettings.extension -eq 'auto') {
        # pack the documentbody field from annotations, by converting it from binary to base 64 encoding
        $documentbodyfield = $recordData.record.field | Where-Object {$_.name -eq 'documentbody'}

        if($documentbodyfield) {
            $relativePath = $documentbodyfield.path
            $documentbodypath = Join-Path -Path $recordsFolder -ChildPath $relativePath
            Write-Verbose "Loading file $documentbodypath"
            
            $documentbodyBytes = Get-Content -Path $documentbodypath -Encoding Byte -Raw
            $documentbodybase64 = [Convert]::ToBase64String($documentbodyBytes)
            $documentbodyfield.SetAttribute("value", $documentbodybase64)

            $documentbodyfield.RemoveAttribute("path")

            if($FieldSettings.hash) {
                $documentbodyfield.RemoveAttribute("hash")
            }
        }
    } else {
        $field = $record.field | Where-Object {$_.name -eq $FieldSettings.field}

        if($field) {
            $relativePath = $field.path
            $filePath = Join-Path -Path $RecordsFolder -ChildPath $relativePath
            Write-Verbose "Loading file $filePath"

            $value = Get-Content -Path $filePath -Encoding UTF8 -Raw

            if($relativePath.EndsWith(".json") -and $FieldSettings.format) {
                $value = [Newtonsoft.Json.Linq.JToken]::Parse($value).ToString([Newtonsoft.Json.Formatting]::None)
            }

            $encoded = [System.Web.HttpUtility]::HtmlEncode($value)
            $field.SetAttribute("value", $encoded)
            
            $field.RemoveAttribute("path")

            if($FieldSettings.hash) {
                $field.RemoveAttribute("hash")
            }
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
        $settings = LoadSettingsFile -Path $SettingsFile

        ExtractData -Path $dataPath -DestinationPath $DestinationPath -Settings $settings
        ExtractSchema -Path $schemaPath -DestinationPath $DestinationPath
        CreateManifest -Path $DestinationPath -Settings $settings
    } elseif($Pack)  {

        $settingsPath = Join-Path -Path $Path -ChildPath "settings.json"

        if((Test-Path -Path $settingsPath) -eq $false) {
            Write-Error -Message "Could not find a settings.json file at $settingsPath. If the unpacked folder at $Path was created with Adoxio.Dynamics.DevOps, first run Compress-Data from Adoxio.Dynamics.DevOps on the unpacked folder to create the zip file, and then run Expand-Data with this version of CrmDataPackager to generate a compatible unpacked folder." -ErrorAction Stop
        }

        Write-Verbose "Loading file $settingsPath"
        $settings = ConvertFrom-Json -InputObject (Get-Content -Path $settingsPath -Raw)

        if($settings.version.StartsWith("1.0")) {
            Write-Error -Message "The unpacked folder at $Path was created with an incompatible version of CrmConfigurationPackager ($($settings.version)). To use Expand-CrmData from this version of CrmConfigurationPackager ($($MyInvocation.MyCommand.Module.Version)), first run Compress-Data from CrmConfigurationPackager v1.0 on the unpacked folder to create the zip file, and then run Expand-Data with this version of CrmDataPackager to generate a compatible unpacked folder." -ErrorAction Stop
        }

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
            PackData -Path $Path -DestinationPath $extractPath -Settings $settings
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

function GetFileNameField {
    param (
        $DefaultFileNameField,
        $EntityField
    )

    $fileNameField = if($EntityField -and 'fileNameField' -in $EntityField.PSObject.Properties.Name) { $EntityField.fileNameField } else { $DefaultFileNameField }

    return $fileNameField
}

function LoadFieldSettings {
    param (
        $SettingsField
    )

    # the default settings for an entity
    $fieldSettings = [PSCustomObject]@{
        field = ""
        fileNameField = "id"
        extension = ".txt"
        format = $false
        hash = $true
    }

    if($Field) {
        foreach($property in $Field.PSObject.Properties) {
            if($property.Name -in $fieldSettings.PSObject.Properties.Name) {
                $fieldSettings."$($property.Name)" = $property.Value
            }
        }
    }

    return $fieldSettings
}

function LoadEntitySettings {
    param (
        $Entity,
        $SettingsEntity
    )

    # the default settings for an entity
    $entitySettings = [PSCustomObject]@{
        entity = $Entity.name
        fileNameField = "id"
        extension = ".xml"
    }

    if($SettingsEntity) {
        # overwrite the default settings based on any matching provided values
        foreach($property in $SettingsEntity.PSObject.Properties) {
            if($property.Name -in $entitySettings.PSObject.Properties.Name) {
                $entitySettings."$($property.Name)" = $property.Value
            }
        }
    }

    return $entitySettings
}

function LoadSettingsFile {
    param (
        $Path
    )

    # the default settings
    $settings = [PSCustomObject]@{
        entities = @()
    }

    $fileSettings = ConvertFrom-Json (Get-Content -Raw -Path $Path)

    # overwrite the default settings based on any matching provided values
    foreach($property in $settings.PSObject.Properties) {
        if(Get-Member -InputObject $fileSettings -Name $property.Name) {
            $settings."$($property.Name)" = $fileSettings."$($property.Name)"
        }
    }

    return $settings
}
