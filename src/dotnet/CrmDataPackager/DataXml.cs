using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;

namespace CrmDataPackager
{
    public class DataXml
    {
        public XmlDocument XmlDocument;

        public DataXml(string folder, string filename)
        {
            var path = Path.Combine(folder, filename);
            XmlDocument = new XmlDocument();
            XmlDocument.Load(path);
        }

        public IEnumerable<EntityData> GetEntities()
        {
            foreach (XmlElement entity in XmlDocument.SelectNodes("entities/entity"))
            {
                yield return new EntityData(entity);
            }
        }
    }
}
