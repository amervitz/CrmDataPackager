using System.ComponentModel;

namespace CrmDataPackager
{
    public class FieldSettings
    {
        public string Field { get; set; }

        [DefaultValue("id")]
        public string FileNameField { get; set; }

        [DefaultValue(".txt")]
        public string Extension { get; set; }

        [DefaultValue(false)]
        public bool Format { get; set; }

        [DefaultValue(true)]
        public bool Hash { get; set; }

        public FieldSettings Clone()
        {
            return (FieldSettings)MemberwiseClone();
        }
    }
}
