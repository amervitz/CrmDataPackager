using System.Collections.Generic;
using System.ComponentModel;

namespace CrmDataPackager
{
    public class EntitySettings
    {
        public string Entity { get; set; }

        public string FileNameField { get; set; }

        public string FileNameSuffixField { get; set; }

        public string Extension { get; set; } = ".xml";

        public FieldsSortOrder? FieldsSortOrder { get; set; }

        public List<FieldSettings> Fields { get; set; } = new List<FieldSettings>();

        public EntitySettings()
        {
        }

        public EntitySettings(string entity)
        {
            Entity = entity;
        }

        public EntitySettings Clone()
        {
            return (EntitySettings)MemberwiseClone();
        }

        public void Inherit(EntitySettings settings)
        {
            if(settings != null)
            {
                FileNameField = FileNameField ?? settings.FileNameField;
                FileNameSuffixField = FileNameSuffixField ?? settings.FileNameSuffixField;
                Extension = Extension ?? settings.Extension;
                FieldsSortOrder = FieldsSortOrder ?? settings.FieldsSortOrder;
            }
        }
    }
}
