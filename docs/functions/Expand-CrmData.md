# Expand-CrmData

## Synopsis
Extracts a Configuration Migration tool data .zip file and decomposes the contents into separate files and folders.

## Description
This function extracts a Configuration Migration tool generated data zip file's contents into separate files and folders for each component.

The folder structure used is loosely based upon the original XML structure. The heirarchy used and the choice of components unpacked into separate files and folders has been chosen to support efficient file diffing and history tracking in source control systems.

- Each entity is separated in its own folder, named using the entity logical name.
- Each record is stored in its own .xml file inside the entity folder, named using the record ID.
- Each many-to-many relationship for each record is stored in its own .xml file within subfolders of the entity folder, with the subfolder named using the relationship name and the record named using the record ID.
- Field values for some entities are stored in their own files within subfolders of the entity folder, with the subfolder named using the field logical name and the field value named using the record ID.

Component | File Path | Description
----------| --------- | -----------
Entity | `entity_logical_name` | A folder for storing the entity data.
Entity schema | `entity_logical_name`/data_schema.xml | The schema of the entity.
Record | `entity_logical_name`/records/`record_id`.xml | The record XML.
Field | `entity_logical_name`/records/`field_logical_name`/`record_id`.`extension` | The field value for a record. This is used to extract the contents of special-purpose text fields into files so that they can be easily viewed in their original format.<br><br>The default settings will extract file attachments stored as base64 encoded strings in annotations to separate files.<br><br>The default settings will extract portal fields that store HTML, JavaScript, and JSON into separate files.<br><br>Refer to [settings.json](/src/CrmDataPackager/settings.json) for the default settings for the entities whose fields are stored in their own files. The fields list can be customized by creating a custom version of this file and supplying it with the `ConfigurationPath` parameter.<br><br>Refer to the [settings file documentation](/docs/Settings-File.md) for details about the file format and authoring a custom settings file.
M2M Relationship | `entity_logical_name`/m2mrelationships/`m2m_relationship_name`/`record_id`.xml | The many-to-many XML for a record.
CrmDataPackager settings | settings.json | A copy of the CrmDataPackager settings used during unpacking, including an extra `version` property  indicating the module verison used, and a `timestamp` property indicating when the unpacked folder was created. The file will by contain the default settings from [settings.json](/src/CrmDataPackager/settings.json), or the settings specified by the `ConfigurationPath` parameter.
Trimmed data.xml | data.xml | The original data.xml file stripped of all entity data that has been unpacked into separate files for each entity.<br><br>The top-level entity elements remain to support packing.
Trimmed data_schema.xml | data_schema.xml | The original data_schema.xml file stripped of all entity schema that has been unpacked into separate data_schema.xml files for each entity.<br><br>The top-level entity elements remain to support packing.
[Content_Types].xml | [Content_Types].xml | The unmodified [Content_Types].xml file from the data zip file.

## Parameters
Parameter | Type | Description | Required? | Default Value
--------- | -----| ----------- | --------- | -------------
ZipFile | string | The file path to the Configuration Migration tool generated data zip file. | true | |
Folder | string | The folder path to create with the unpacked records. | true | |
[SettingsFile](/docs/Settings-File.md) | string | The path to a settings file to specify entity fields to extract to files. | false | See [settings.json](/src/CrmDataPackager/settings.json) |

## Examples

## Example 1
This example extracts the data zip file exported from the AdventureWorks organization and unpacks the contents to the specified `-Folder`.
```powershell
Expand-CrmData -ZipFile 'C:\temp\export\AdventureWorksData.zip' -Folder 'C:\temp\data\AdventureWorks'
```

## Example 2
This example extracts the data zip file exported from the AdventureWorks organization, unpacks the contents to the specified -Folder, and unpacks the contents using the settings in the specified -[SettingsFile](/docs/Settings-File.md).

```powershell
Expand-CrmData -ZipFile 'C:\temp\export\AdventureWorksData.zip' -Folder 'C:\temp\data\AdventureWorks' -SettingsFile 'C:\temp\AdventureWorks.json'
```
