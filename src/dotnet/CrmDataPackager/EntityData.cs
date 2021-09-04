using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;

namespace CrmDataPackager
{
    public class EntityData
    {
        public XmlElement XmlElement;

        public EntityData(XmlElement entityElement)
        {
            XmlElement = entityElement;
        }

        public string Name => XmlElement.GetAttribute("name");

        public DirectoryInfo CreateEntityFolder(string targetFolderPath)
        {
            var entityFolder = Path.Combine(targetFolderPath, Name);
            var entityDirectory = Directory.CreateDirectory(entityFolder);
            return entityDirectory;
        }

        public DirectoryInfo CreateRecordsFolder(DirectoryInfo entityDirectory)
        {
            return Directory.CreateDirectory(Path.Combine(entityDirectory.FullName, "records"));
        }

        public IEnumerable<Record> GetRecords()
        {
            foreach (XmlElement record in XmlElement.SelectNodes("records/record"))
            {
                yield return new Record(record);
            }
        }
    }
}
