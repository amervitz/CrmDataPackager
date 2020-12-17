# Compress-CrmData

## Synopsis
Packs and zips a folder of Configuration Migration tool generated files previously created from the `Expand-CrmData` cmdlet.

## Description
This function packs and zips the folders and files created from `Expand-CrmData` processing of a Configuration Migration tool generated zip file.

## Parameters
| Parameter  | Type | Description | Required? | Default Value |
|---|---|---|---|---|
| Folder | String | The folder path of an unpacked Configuation Migration tool generated zip file. | true | |
| ZipFile | String | The zip file path to create after packing the configuration data files. | true | |

## Examples

## Example 1
This example processes the contenets of the specified `-Folder` with an already exported data set from an AdventureWorks organization and saves the packed zip file to the specified `-ZipFile`.
```powershell
 Compress-CrmData -Folder 'C:\temp\data\AdventureWorks' -ZipFile 'C:\temp\packed\AdventureWorksData.zip'
```
