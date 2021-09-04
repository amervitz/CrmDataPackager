using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Xml;

namespace CrmDataPackager
{
    public class CrmDataFileExtractor
    {
        private readonly ILogger _logger;

        public CrmDataFileExtractor(ILogger logger)
        {
            _logger = logger;
        }

        public CrmDataFolder Extract(string folderPath, string settingsFilePath)
        {
            _logger.LogTrace($"Loading file {settingsFilePath}");
            var settingsFile = SettingsFile.Load(settingsFilePath);

            var dataPath = ExtractData(folderPath, settingsFile);
            var schemaPath = ExtractSchema(folderPath);
            var settingsPath = CreateSettingsFile(folderPath, settingsFile);

            return new CrmDataFolder
            {
                FolderPath = folderPath,
                DataPath = dataPath,
                SchemaPath = schemaPath,
                SettingsPath = settingsPath
            };
        }

        private string ExtractSchema(string destinationPath)
        {
            var schemaPath = Path.Combine(destinationPath, "data_schema.xml");
            var xml = new XmlDocument();
            _logger.LogTrace($"Loading file {schemaPath}");
            xml.Load(schemaPath);

            foreach (XmlElement entity in xml.SelectNodes("entities/entity"))
            {
                var entityFolder = new DirectoryInfo(Path.Combine(destinationPath, entity.GetAttribute("name")));
                if (entityFolder.Exists)
                {
                    var entitySchemaPath = Path.Combine(entityFolder.FullName, "data_schema.xml");
                    _logger.LogTrace($"Writing file {entitySchemaPath}");
                    File.WriteAllText(entitySchemaPath, FormatXml(entity.OuterXml), Encoding.UTF8);
                }
                else
                {
                    _logger.LogTrace($"No data for entity {entity.GetAttribute("name")}, skipping schema extract");
                }
            }

            _logger.LogDebug("creating root data_schema.xml");
            var rootSchema = CreateRootSchema(xml, destinationPath);
            var targetSchemaPath = Path.Combine(destinationPath, "data_schema.xml");
            File.WriteAllText(targetSchemaPath, FormatXml(rootSchema.OuterXml), Encoding.UTF8);
            return targetSchemaPath;
        }

        private string ExtractData(string targetFolderPath, SettingsFile settingsFile)
        {
            var dataXml = new DataXml(targetFolderPath, "data.xml");
            var schemaXml = new SchemaXml(targetFolderPath, "data_schema.xml");

            foreach (var entityData in dataXml.GetEntities())
            {
                _logger.LogDebug($"Processing entity {entityData.Name}");

                var entityFolder = entityData.CreateEntityFolder(targetFolderPath);
                var recordsFolder = entityData.CreateRecordsFolder(entityFolder);

                var entitySettings = settingsFile.GetEntitySettingsOrDefault(entityData.Name);

                var entitySchema = schemaXml.GetEntity(entityData.Name);

                foreach (var record in entityData.GetRecords())
                {
                    _logger.LogDebug($"Processing record {record.Id}");

                    // process each field
                    foreach (var fieldData in record.GetFields())
                    {
                        var fieldSettings = settingsFile.GetFieldSettingsOrDefault(entityData.Name, fieldData.Name);

                        if (fieldSettings.Remove.GetValueOrDefault())
                        {
                            record.RemoveField(fieldData);
                            continue;
                        }

                        if (fieldData.FieldType == FieldType.Lookup && fieldSettings.RemoveLookupEntityName.GetValueOrDefault())
                        {
                            _logger.LogDebug($"Removing lookupentityname attribute from field {fieldData.Name}");
                            fieldData.RemoveLookupEntityName();
                        }

                        if(fieldSettings.FileNameField != null)
                        {
                            WriteFileAndUpdateRecord(entityData.XmlElement, entitySchema, recordsFolder, record.XmlElement, fieldSettings);
                        }
                    }

                    var fileNameField = GetFileNameField(entitySchema, entitySettings.FileNameField);
                    var fileNamePrefix = GetFileNamePrefix(record.XmlElement, fileNameField); ;
                    var escapedFileNamePrefix = EscapeFileName(fileNamePrefix);
                    var fileExtension = entitySettings.Extension;
                    var fileName = $"{escapedFileNamePrefix}{fileExtension}";

                    var recordPath = Path.Combine(recordsFolder.FullName, fileName);

                    if (File.Exists(recordPath))
                    {
                        var existingFileName = fileName;
                        fileName = $"{escapedFileNamePrefix} {record.Id}{fileExtension}";

                        _logger.LogWarning($"Naming {entityData.Name} file {fileName} to avoid conflict with existing file {existingFileName}");
                    }

                    recordPath = Path.Combine(recordsFolder.FullName, fileName);

                    _logger.LogTrace($"Writing file {recordPath}");

                    if (entitySettings.FieldsSortOrder.GetValueOrDefault() != FieldsSortOrder.None)
                    {
                        record.SortFields(entitySettings.FieldsSortOrder.Value);
                    }

                    File.WriteAllText(recordPath, FormatXml(record.XmlElement.OuterXml), Encoding.UTF8);
                }

                var m2mrelationships = entityData.XmlElement.SelectSingleNode("m2mrelationships");
                if (m2mrelationships != null && m2mrelationships.HasChildNodes)
                {
                    var m2mrelationshipsPath = Path.Combine(entityFolder.FullName, "m2mrelationships");
                    _logger.LogTrace($"Creating folder {m2mrelationshipsPath}");
                    var m2mrelationshipsFolder = Directory.CreateDirectory(m2mrelationshipsPath);

                    foreach (XmlElement m2mrelationship in entityData.XmlElement.SelectNodes("m2mrelationships/m2mrelationship"))
                    {
                        var m2mrelationshipnamePath = Path.Combine(m2mrelationshipsFolder.FullName, m2mrelationship.GetAttribute("m2mrelationshipname"));
                        var m2mrelationshipnameFolder = new DirectoryInfo(m2mrelationshipnamePath);
                        if (!m2mrelationshipnameFolder.Exists)
                        {
                            _logger.LogTrace($"Creating folder {m2mrelationshipnamePath}");
                            m2mrelationshipnameFolder = Directory.CreateDirectory(m2mrelationshipnamePath);
                        }

                        var m2mrelationshipPath = Path.Combine(m2mrelationshipnameFolder.FullName, $"{m2mrelationship.GetAttribute("sourceid")}.xml");
                        _logger.LogTrace($"Writing file {m2mrelationshipPath}");
                        File.WriteAllText(m2mrelationshipPath, FormatXml(m2mrelationship.OuterXml), Encoding.UTF8);
                    }
                }
            }

            var rootData = CreateRootSchema(dataXml.XmlDocument, targetFolderPath);

            // write back the condensed version of the data.xml file to the root of the folder
            var targetDataPath = Path.Combine(targetFolderPath, "data.xml");
            File.WriteAllText(targetDataPath, FormatXml(rootData.OuterXml), Encoding.UTF8);
            return targetDataPath;
        }

        private string CreateSettingsFile(string path, SettingsFile settingsFile)
        {
            settingsFile.Version = Project.Version;
            settingsFile.Timestamp = DateTime.UtcNow;

            var settingsPath = Path.Combine(path, "settings.json");
            _logger.LogTrace($"Writing file {settingsPath}");
            settingsFile.Write(settingsPath);
            return settingsPath;
        }

        private XmlDocument CreateRootSchema(XmlDocument xml, string dataPath)
        {
            var rootSchema = xml.CloneNode(true) as XmlDocument;

            foreach (XmlElement entity in rootSchema.SelectNodes("entities/entity"))
            {
                var entityFolder = new DirectoryInfo(Path.Combine(dataPath, entity.GetAttribute("name")));

                if (entityFolder.Exists)
                {
                    // remove extraneous attributes that aren't helpful when viewing the file
                    var removeAttributes = entity.Attributes.Cast<XmlAttribute>().Where(x => x.Name != "name" && x.Name != "displayname").ToList();
                    foreach (var remove in removeAttributes)
                    {
                        _logger.LogDebug($"Removing attribute {remove.Name}");
                        entity.RemoveAttribute(remove.Name);
                    }

                    // remove child elements and make the entity element self-closing tag
                    entity.IsEmpty = true;

                }
                else
                {
                    _logger.LogTrace($"Removing {entity.GetAttribute("name")} from root schema file due to no data for entity");
                    rootSchema.SelectSingleNode("entities").RemoveChild(entity);
                }
            }

            return rootSchema;
        }

        internal static string FormatXml(string xml, int indent = 2)
        {
            var stringWriter = new StringWriter();
            var xmlWriter = new XmlTextWriter(stringWriter);
            xmlWriter.Formatting = Formatting.Indented;
            xmlWriter.Indentation = indent;
            var xmlDocument = new XmlDocument();
            xmlDocument.LoadXml(xml);
            xmlDocument.WriteContentTo(xmlWriter);
            xmlWriter.Flush();
            stringWriter.Flush();
            return stringWriter.ToString();
        }

        public void WriteFileAndUpdateRecord(XmlElement entity, XmlElement entitySchema, DirectoryInfo recordsFolder, XmlElement record, FieldSettings fieldSettings)
        {
            var field = record.SelectSingleNode($"field[@name='{fieldSettings.Field}']") as XmlElement;

            if (field == null)
            {
                _logger.LogDebug($"no match for field {fieldSettings.Field}");
                return;
            }

            _logger.LogDebug($"matched field {fieldSettings.Field}");


            if (entity.GetAttribute("name") == "annotation" && fieldSettings.Field == "documentbody" && fieldSettings.Extension == "auto")
            {
                var documentbodyFolder = Path.Combine(recordsFolder.FullName, "documentbody");
                Directory.CreateDirectory(documentbodyFolder);

                // unpack the documentbody field from annotations, by converting it from base 64 encoding and saving to the file system
                var annotationFileNameField = record.SelectSingleNode($"field[@name='filename']") as XmlElement;

                var documentbody = Convert.FromBase64String(field.GetAttribute("value"));
                string documentbodyPath;
                string documentbodyfilename;
                if (fieldSettings.FileNameField != "id" && annotationFileNameField != null)
                {
                    documentbodyfilename = EscapeFileName(annotationFileNameField.GetAttribute("value"));
                    documentbodyPath = Path.Combine(documentbodyFolder, documentbodyfilename);

                    if (File.Exists(documentbodyPath))
                    {
                        var existingFileName = documentbodyfilename;
                        var annotationFileExtension = Path.GetExtension(documentbodyfilename);
                        documentbodyfilename = $"{documentbodyfilename} {record.GetAttribute("id")}{annotationFileExtension}";

                        _logger.LogWarning($"Naming {entity.GetAttribute("name")}\\{field.GetAttribute("name")} file {documentbodyfilename} to avoid conflict with existing file {existingFileName}");
                    }
                }
                else
                {
                    var annotationFileExtension = annotationFileNameField == null ? null : Path.GetExtension(annotationFileNameField.GetAttribute("value"));
                    documentbodyfilename = $"{record.GetAttribute("id")}{annotationFileExtension}";
                }

                documentbodyPath = Path.Combine(documentbodyFolder, documentbodyfilename);

                _logger.LogTrace($"Writing file {documentbodyPath}");
                File.WriteAllBytes(documentbodyPath, documentbody);

                // set the documentbody field value to the generated unpacked filename so the base 64 encoded text isn"t written to disk and the file can be easily identified
                field.RemoveAttribute("value");
                var path = Path.Combine("documentbody", documentbodyfilename);
                field.SetAttribute("path", path);


                if (fieldSettings.Hash.GetValueOrDefault())
                {
                    var md5 = GetBytesHashMD5(documentbody);
                    field.SetAttribute("hash", md5);
                }
            }
            else
            {
                if (entity.GetAttribute("name") == "adx_contentsnippet" && fieldSettings.Field == "adx_value" && fieldSettings.Extension == "auto")
                {
                    // determine if the type is text or html, set the file extension accordingly
                    var type = record.SelectSingleNode("field[@name='adx_type']") as XmlElement;
                    fieldSettings = fieldSettings.Clone();
                    fieldSettings.Extension = ".txt";
                    if (type?.GetAttribute("value") == "756150001")
                    {
                        fieldSettings.Extension = ".html";
                    }
                }

                var fileInfo = WriteTextFile(recordsFolder, record, field, fieldSettings, entitySchema);

                if(fileInfo.Path != "")
                {
                    // remove the value and set the path so the original text isn't written to back to the record
                    field.RemoveAttribute("value");
                    field.SetAttribute("path", fileInfo.Path);
                }

                if (fieldSettings.Hash.GetValueOrDefault() && fileInfo.Hash != "")
                {
                    // set the unpacked hash so the file can be easily identified
                    field.SetAttribute("hash", fileInfo.Hash);
                }
            }
        }

        private (string Path, string Hash) WriteTextFile(DirectoryInfo recordsFolder, XmlElement record, XmlElement field, FieldSettings fieldSettings, XmlElement entitySchema)
        {
            // todo: make a config setting
            var htmlDecode = true;

            var value = htmlDecode? WebUtility.HtmlDecode(field.GetAttribute("value")) : field.GetAttribute("value");

            var fileNameField = GetFileNameField(entitySchema, fieldSettings.FileNameField);

            var fileNamePrefix = GetFileNamePrefix(record, fileNameField);

            if (fieldSettings.FileNameField != "id")
            {
                fileNamePrefix = EscapeFileName(fileNamePrefix);
            }

            if (fieldSettings.Extension == ".json" && fieldSettings.Format.GetValueOrDefault())
            {
                value = Newtonsoft.Json.Linq.JToken.Parse(value).ToString();
            }

            var fileName = $"{fileNamePrefix}{fieldSettings.Extension}";
            var folder = Path.Combine(recordsFolder.FullName, field.GetAttribute("name"));
            var path = Path.Combine(folder, fileName);

            if (fieldSettings.FileNameField != "id" && File.Exists(path))
            {
                var existingFileName = fileName;
                fileName = $"{fileNamePrefix} {record.GetAttribute("id")}{fieldSettings.Extension}";
                folder = Path.Combine(recordsFolder.FullName, field.GetAttribute("name"));

                _logger.LogWarning($"Naming {folder} file {fileName} to avoid conflict with existing file {existingFileName}");

                path = Path.Combine(folder, fileName);
            }

            Directory.CreateDirectory(folder);
            _logger.LogTrace($"Writing file {path}");
            File.WriteAllText(path, value, Encoding.UTF8);

            if(fileNameField != field.GetAttribute("name"))
            {
                // save the new file's relative path to the field so it can be found via the original record
                var relativePath = Path.Combine(field.GetAttribute("name"), fileName);

                // save the new file's hash to the field so changes can be identified via the original record
                if (fieldSettings.Hash.GetValueOrDefault())
                {
                    var hash = GetTextHashMD5(value);

                    return (relativePath, hash);
                }
                else
                {
                    return (relativePath, "");

                }
            }
            else
            {
                return ("", "");
            }
        }

        private string GetFileNameField(XmlElement entitySchema, string fileNameField)
        {
            if (fileNameField == "primaryidfield")
            {
                return entitySchema.GetAttribute("primaryidfield");
            }
            else if (fileNameField == "primarynamefield")
            {
                return entitySchema.GetAttribute("primarynamefield");
            }
            else
            {
                return fileNameField;
            }
        }

        private string GetFileNamePrefix(XmlElement record, string fileNameField)
        {
            if (fileNameField == "id")
            {
                return record.GetAttribute("id");
            }
            
            if (fileNameField != null)
            {
                if (record.SelectSingleNode($"field[@name='{fileNameField}']") is XmlElement field)
                {
                    return field.GetAttribute("value");
                }
            }

            return record.GetAttribute("id");
        }

        public string EscapeFileName(string fileName)
        {
            var specialCharacters = new[] { '\\', '/', ':', '*', '*', '?', '"', '<', '>', '|' }; // windows reserved characters

            var fileNameChars = fileName.ToCharArray();

            var fileNameSb = new StringBuilder();

            for (var i = 0; i < fileNameChars.Length; i++)
            {
                if (specialCharacters.Contains(fileNameChars[i]))
                {
                    fileNameSb.Append(Uri.EscapeDataString(fileNameChars[i].ToString()));
                }
                else
                {
                    fileNameSb.Append(fileNameChars[i]);
                }
            }

            var escaped = fileNameSb.ToString();
            return escaped;
        }

        private string GetBytesHashMD5(byte[] bytes)
        {
            var md5 = MD5.Create();
            var hashBytes = md5.ComputeHash(bytes);

            var hash = new StringBuilder();

            for (var i = 0; i < hashBytes.Length; i++)
            {
                hash.Append(hashBytes[i].ToString("X2"));
            }

            return hash.ToString();
        }

        private string GetTextHashMD5(string text)
        {
            var bytes = Encoding.UTF8.GetBytes(text);
            var hash = GetBytesHashMD5(bytes);
            return hash;
        }
    }
}
