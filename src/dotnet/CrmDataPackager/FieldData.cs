using System.Xml;

namespace CrmDataPackager
{
    public class FieldData
    {
        internal XmlElement XmlElement;

        public FieldData(XmlElement field)
        {
            XmlElement = field;
        }

        public string Name => XmlElement.GetAttribute("name");

        public FieldType FieldType => XmlElement.HasAttribute("lookupentity") && XmlElement.GetAttribute("lookupentity") != "" ? FieldType.Lookup : FieldType.Standard;

        public void RemoveLookupEntityName()
        {
            XmlElement.RemoveAttribute("lookupentityname");
        }
    }
}