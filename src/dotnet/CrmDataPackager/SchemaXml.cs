using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;

namespace CrmDataPackager
{
    public class SchemaXml
    {
        private XmlDocument _xml;

        public SchemaXml(string folder, string filename)
        {
            var path = Path.Combine(folder, filename);
            _xml = new XmlDocument();
            _xml.Load(path);
        }

        public XmlElement GetEntity(string entityName) => _xml.SelectSingleNode($"entities/entity[@name='{entityName}']") as XmlElement;
    }
}
