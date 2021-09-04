using System;
using System.Collections.Generic;
using System.Linq;
using System.Xml;

namespace CrmDataPackager
{
    public class Record
    {
        public XmlElement XmlElement;

        public Record(XmlElement record)
        {
            XmlElement = record;
        }

        public string Id => XmlElement.GetAttribute("id");

        public IEnumerable<FieldData> GetFields()
        {
            foreach (XmlElement field in XmlElement.SelectNodes("field"))
            {
                yield return new FieldData(field);
            }
        }

        public void SortFields(FieldsSortOrder fieldsSortOrder)
        {
            if (fieldsSortOrder == FieldsSortOrder.None)
            {
                return;
            }

            var fields = XmlElement.SelectNodes("field");
            var fieldsList = new List<XmlElement>(fields.Count);

            foreach (XmlElement field in fields)
            {
                fieldsList.Add(field);
            }

            var sortedFields = fieldsSortOrder == FieldsSortOrder.Ascending ? fieldsList.OrderBy(f => f.GetAttribute("name")) : fieldsList.OrderByDescending(f => f.GetAttribute("name"));

            foreach (XmlNode field in fields)
            {
                XmlElement.RemoveChild(field);
            }

            foreach (XmlNode field in sortedFields)
            {
                XmlElement.AppendChild(field);
            }
        }

        public void RemoveField(FieldData fieldData)
        {
            XmlElement.RemoveChild(fieldData.XmlElement);
        }
    }
}