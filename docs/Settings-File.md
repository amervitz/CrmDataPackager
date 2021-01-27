# Settings File

The `Expand-CrmData` function supports a `SettingsFile` parameter to a JSON file that defines settings for how entities and their fields should be unpacked. This parameter is optional and when not specified the settings file at [/src/CrmDataPackager/settings.json](/src/CrmDataPackager/settings.json) will be used.

This page describes the full schema and rules for the settings in this file. When creating a custom settings file, properties with default values can be omitted.

```JSON
{
  "entities": [
    {
      "entity": "entity_logical_name",
      "fileNameField": "field_logical_name",
      "extension": "file_extension",
      "fields": [
        {
          "field": "field_logical_name",
          "fileNameField": "field_logical_name",
          "extension": "file_extension",
          "format": "true_or_false",
          "hash": "true_or_false",
        }
      ]
    }
  ]
}
```

### Top level structure
The `entities` property is the top level property for defining the list of entities to unpack following defined rules.

Each entity can have one or more fields that will each be unpacked to their own separate file.

### entity properties

#### entity
The logical name of an entity whose fields are to be unpacked to separate files.

**Example**
```JSON
"entity": "adx_snippet"
```

#### fileNameField
The field to use for determining the file name of the record.

**Example**
```JSON
"fileNameField": "adx_name"
```

**Default value**

`id`

**Allowed values**

- `id`: The file name will be based on the record ID.
- A field logical in the record XML. The file name will use the value of the field.
  - When the generated file name conflicts with an existing file due to multiple records sharing the same name, the file name will instead use the record ID.

#### extension
The file extension to add to the file name of the record.

**Example**
```JSON
"extension": ".xml"
```

**Default value**

`.xml`

**Allowed values**

Any file extension.

### field properties

#### field
The logical name of a field whose value should be unpacked to its own file.

**Example**
```JSON
"field": "adx_copy"
```

#### fileNameField
The field to use for determining the file name of the record.

**Example**
```JSON
"fileNameField": "adx_name"
```

**Default value**

`id`

**Allowed values**

- `id`: The file name will be based on the record ID.
- A field logical in the record XML. The file name will use the value of the field.
  - When the generated file name conflicts with an existing file due to multiple records sharing the same name, the file name will instead use the record ID.

#### extension

The file extension add to the filename containing the field's value.

**Example**
```JSON
"extension": ".html"
```

**Default value**

- `.txt` 
- See [settings.json](/src/CrmDataPackager/settings.json) for suggested file extensions for fields on various entities.

**Supported values**
- any valid file extension
- `auto`
  - for the `annotation` entity, the file extension will be extracted from the filename field
  - for the `adx_snippet` entity, the file extension will be automatically determined as `.html` or `.txt` based on whether the snippet has been configured as HTML or text

#### format

For certain supported file types, the field contents will be formatted prior to being written to disk.

**Example**
```JSON
"format": true
```

**Default value**

- `false` 
- See [settings.json](/src/CrmDataPackager/settings.json) for the default entities with formatting specified for fields

**Supported values**
- `true`
  - for files with a `.json` extension, the contents will be pretty-print formatted
- `false`

#### hash

An md5 hash is generated based on the field contents written to disk, and the md5 is added to the record XML. This helps to identify records whose fields have changed.

**Example**
```JSON
"hash": true
```

**Default value**

- `true` 

**Supported values**
- `true`
- `false`