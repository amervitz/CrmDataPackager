using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace CrmDataPackager
{
    public class SettingsFile
    {
        public string Version { get; set; }

        public DateTime? Timestamp { get; set; }

        public List<EntitySettings> Entities { get; set; } = new List<EntitySettings>();

        public static SettingsFile Load(string path)
        {
            var content = File.ReadAllText(path);
            var settings = new JsonSerializerSettings()
            {
                DefaultValueHandling = DefaultValueHandling.Populate
            };

            var settingsFile = JsonConvert.DeserializeObject<SettingsFile>(content, settings);
            return settingsFile;
        }

        public string ToJson()
        {
            var settings = new JsonSerializerSettings()
            {
                Formatting = Formatting.Indented,
                DefaultValueHandling = DefaultValueHandling.Ignore,
                ContractResolver = new CamelCasePropertyNamesContractResolver()
            };

            var json = JsonConvert.SerializeObject(this, settings);
            return json;
        }

        public void Write(string path)
        {
            var contents = ToJson();
            File.WriteAllText(path, contents, Encoding.UTF8);
        }
    }
}
