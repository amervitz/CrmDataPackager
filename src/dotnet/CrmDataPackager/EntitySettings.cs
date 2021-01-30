using System.Collections.Generic;
using System.ComponentModel;

namespace CrmDataPackager
{
    public class EntitySettings
    {
        public string Entity { get; set; }

        [DefaultValue("id")]
        public string FileNameField { get; set; }

        [DefaultValue(".xml")]
        public string Extension { get; set; }

        public List<FieldSettings> Fields { get; set; } = new List<FieldSettings>();

        public EntitySettings()
        {
        }

        public EntitySettings(string entity)
        {
            Entity = entity;
            FileNameField = "id";
            Extension = ".xml";
        }
    }
}
