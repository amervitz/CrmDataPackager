using System;
using System.ComponentModel;

namespace CrmDataPackager
{
    public class FieldSettings
    {
        public FieldSettings(string fieldName)
        {
            Field = fieldName;
        }

        public string Field { get; set; }

        public string FileNameField { get; set; }

        public string Extension { get; set; }

        public bool? Format { get; set; }

        public bool? Hash { get; set; }

        public bool? RemoveLookupEntityName { get; set; }

        public bool? Remove { get; set; }

        public FieldSettings Clone()
        {
            return (FieldSettings)MemberwiseClone();
        }

        public void Inherit(FieldSettings settings)
        {
            if (settings != null)
            {
                FileNameField = FileNameField ?? settings.FileNameField;
                Extension = Extension ?? settings.Extension;
                Format = Format ?? settings.Format;
                Hash = Hash ?? settings.Hash;
                RemoveLookupEntityName = RemoveLookupEntityName ?? settings.RemoveLookupEntityName;
                Remove = Remove ?? settings.Remove;
            }
        }
    }
}
