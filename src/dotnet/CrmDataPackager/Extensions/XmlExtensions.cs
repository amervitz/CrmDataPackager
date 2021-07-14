using System.Xml;

namespace CrmDataPackager.Extensions
{
    public static class XmlExtensions
    {
        public static object GetRecordValue(this XmlAttribute attribute)
        {
            if (attribute.Value == "True" || attribute.Value == "False")
            {
                return bool.Parse(attribute.Value);
            }
            else
            {
                return attribute.Value;
            }
        }
    }
}
