using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;
using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Xml;

namespace CrmDataPackager
{
    public class CrmDataFolderPacker
    {
        private readonly ILogger _logger;

        public CrmDataFolderPacker(ILogger logger)
        {
            _logger = logger;
        }

        public CrmDataFile Pack(string sourcePath, string targetPath)
        {
            var settingsFilePath = Path.Combine(sourcePath, "settings.json");

            if (File.Exists(settingsFilePath) == false)
            {
                _logger.LogError($"Could not find a settings.json file at {settingsFilePath}. Extract a data file with CrmDataPackager to create a compatible extracted folder.");
                return null;
            }

            _logger.LogTrace($"Loading file {settingsFilePath}");
            var settingsFile = SettingsFile.Load(settingsFilePath);

            if (settingsFile.Version.StartsWith("1.0"))
            {
                _logger.LogError($"The extracted data folder at {sourcePath} was created with an incompatible prior version of CrmDataPackager ({settingsFile.Version}). To create an extracted data folder compatible with this version of CrmDataPackager ({Project.Version}), pack the data folder using the prior version and then extract the data file with this version.");
                return null;
            }

            PackSchema(sourcePath, targetPath);
            PackData(sourcePath, targetPath, settingsFile);
            PackContentTypes(sourcePath, targetPath);

            return new CrmDataFile
            {
                FilePath = targetPath
            };
        }

        private void PackContentTypes(string sourcePath, string targetPath)
        {
            var sourceContentTypesPath = Path.Combine(sourcePath, "[Content_Types].xml");
            var destinationContentTypesPath = Path.Combine(targetPath, "[Content_Types].xml");
            _logger.LogTrace($"Writing file {destinationContentTypesPath}");
            File.Copy(sourceContentTypesPath, destinationContentTypesPath);
        }

        private void PackData(string path, string destinationPath, SettingsFile settingsFile)
        {
            var rootDataPath = Path.Combine(path, "data.xml");

            _logger.LogTrace($"Loading file {rootDataPath}");
            var xml = new XmlDocument();
            xml.Load(rootDataPath);
            var entities = xml.SelectSingleNode("entities");

            foreach (XmlElement entity in xml.SelectNodes("entities/entity"))
            {
                var entityFolder = new DirectoryInfo(Path.Combine(path, entity.GetAttribute("name")));

                if (entityFolder.Exists == false)
                {
                    _logger.LogTrace($"No data for entity {entity.GetAttribute("name")}, skipping data pack");
                    entities.RemoveChild(entity);
                    continue;
                }

                var recordsFolder = new DirectoryInfo(Path.Combine(entityFolder.FullName, "records"));

                // load all the xml files that represent each CRM record
                var recordFiles = Directory.GetFiles(recordsFolder.FullName, "*.xml", SearchOption.TopDirectoryOnly);

                // create the records element where each CRM record will be stored
                var recordsNode = xml.CreateElement("records");

                entity.AppendChild(recordsNode);

                var entitySettings = settingsFile.Entities.Where(e => e.Entity == entity.GetAttribute("name")).FirstOrDefault();

                // read the record xml for each CRM record from disk, and add it to the records element
                foreach (var recordFile in recordFiles)
                {
                    _logger.LogTrace($"Loading file {recordFile}");
                    var recordData = new XmlDocument();
                    recordData.Load(recordFile);

                    if (entitySettings != null)
                    {
                        foreach (var field in entitySettings.Fields)
                        {
                            LoadFileAndUpdateRecord(recordsFolder, recordData.DocumentElement, entity, field);
                        }
                    }

                    var recordDataNode = xml.ImportNode(recordData.DocumentElement, true);
                    recordsNode.AppendChild(recordDataNode);
                }

                // create the stub m2mrelationships element that will be replaced with the m2mrelationships.xml file
                var m2mStubNode = xml.CreateElement("m2mrelationships");
                entity.AppendChild(m2mStubNode);

                // try load the m2mrelationships, if it exists, replace the m2mrelationships node
                var m2mrelationshipsFolderPath = Path.Combine(entityFolder.FullName, "m2mrelationships");
                var m2mrelationshipsFolder = new DirectoryInfo(m2mrelationshipsFolderPath);

                if (m2mrelationshipsFolder.Exists)
                {
                    var m2mrelationshipsFolders = Directory.GetDirectories(m2mrelationshipsFolder.FullName);

                    foreach (var m2mrelationshipFolder in m2mrelationshipsFolders)
                    {
                        var m2mrelationshipFiles = Directory.GetFiles(m2mrelationshipFolder, "*.xml");

                        foreach (var m2mrelationshipFile in m2mrelationshipFiles)
                        {
                            _logger.LogTrace($"Loading file {m2mrelationshipFile}");
                            var m2mrelationshipData = new XmlDocument();
                            m2mrelationshipData.Load(m2mrelationshipFile);
                            var m2mrelationshipDataNode = xml.ImportNode(m2mrelationshipData.DocumentElement, true);
                            m2mStubNode.AppendChild(m2mrelationshipDataNode);
                        }
                    }
                }
            }

            // write the packed version of the data.xml file to the root of the folder
            var dataOutPath = Path.Combine(destinationPath, "data.xml");
            _logger.LogTrace($"Writing file {dataOutPath}");
            File.WriteAllText(dataOutPath, CrmDataFileExtractor.FormatXml(xml.OuterXml), Encoding.UTF8);
        }

        private void LoadFileAndUpdateRecord(DirectoryInfo recordsFolder, XmlElement record, XmlElement entity, FieldSettings fieldSettings)
        {
            if (entity.GetAttribute("name") == "annotation" && fieldSettings.Field == "documentbody" && fieldSettings.Extension == "auto")
            {
                // pack the documentbody field from annotations, by converting it from binary to base 64 encoding
                if (record.SelectSingleNode("field[@name='documentbody']") is XmlElement documentbodyfield)
                {
                    var relativePath = documentbodyfield.GetAttribute("path");

                    if (relativePath == "")
                    {
                        return;
                    }

                    var documentbodypath = Path.Combine(recordsFolder.FullName, relativePath);

                    if (File.Exists(documentbodypath))
                    {
                        _logger.LogTrace($"Loading file {documentbodypath}");
                        var documentbodyBytes = File.ReadAllBytes(documentbodypath);
                        var documentbodybase64 = Convert.ToBase64String(documentbodyBytes);
                        documentbodyfield.SetAttribute("value", documentbodybase64);
                    }
                    else
                    {
                        _logger.LogWarning($"File not found at {documentbodypath}, skipping file.");
                    }

                    documentbodyfield.RemoveAttribute("path");
                    documentbodyfield.RemoveAttribute("hash");
                }
            }
            else
            {
                if (record.SelectSingleNode($"field[@name='{fieldSettings.Field}']") is XmlElement field)
                {
                    var relativePath = field.GetAttribute("path");

                    if (relativePath == "")
                    {
                        return;
                    }

                    var filePath = Path.Combine(recordsFolder.FullName, relativePath);

                    if (File.Exists(filePath))
                    {
                        _logger.LogTrace($"Loading file {filePath}");

                        var value = File.ReadAllText(filePath, Encoding.UTF8);

                        if (relativePath.EndsWith(".json") && fieldSettings.Format.GetValueOrDefault())
                        {
                            value = JToken.Parse(value).ToString(Newtonsoft.Json.Formatting.None);
                        }

                        var encoded = WebUtility.HtmlEncode(value);
                        field.SetAttribute("value", encoded);
                    }
                    else
                    {
                        _logger.LogWarning($"File not found at {filePath}, skipping file.");
                    }

                    field.RemoveAttribute("path");
                    field.RemoveAttribute("hash");
                }
            }
        }

        private void PackSchema(string sourcePath, string targetPath)
        {
            var rootSchemaPath = Path.Combine(sourcePath, "data_schema.xml");
            _logger.LogTrace($"Loading file {rootSchemaPath}");
            var xml = new XmlDocument();
            xml.Load(rootSchemaPath);
            var entities = xml.SelectSingleNode("entities");

            foreach (XmlElement entity in xml.SelectNodes("/entities/entity"))
            {
                var entityFolder = new DirectoryInfo(Path.Combine(sourcePath, entity.GetAttribute("name")));
                if (entityFolder.Exists)
                {
                    var schemaPath = Path.Combine(entityFolder.FullName, "data_schema.xml");
                    _logger.LogTrace($"Loading file {schemaPath}");
                    var entitySchema = new XmlDocument();
                    entitySchema.Load(schemaPath);
                    var entitySchemaNode = xml.ImportNode(entitySchema.DocumentElement, true);
                    entities.ReplaceChild(entitySchemaNode, entity);
                }
                else
                {
                    _logger.LogTrace($"No data for entity {entity.GetAttribute("name")}, skipping schema pack");
                    entities.RemoveChild(entity);
                }
            }


            // write the packed version of the data_schema.xml file to the root of the folder
            var outPath = Path.Combine(targetPath, "data_schema.xml");

            _logger.LogTrace($"Writing file {outPath}");
            File.WriteAllText(outPath, CrmDataFileExtractor.FormatXml(xml.OuterXml), Encoding.UTF8);
        }
    }
}
