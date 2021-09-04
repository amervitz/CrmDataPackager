using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
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
                DefaultValueHandling = DefaultValueHandling.Populate,
            };

            var settingsFile = JsonConvert.DeserializeObject<SettingsFile>(content, settings);

            settingsFile.Entities = settingsFile.Entities ?? new List<EntitySettings>();

            foreach(var entity in settingsFile.Entities)
            {
                entity.Fields = entity.Fields ?? new List<FieldSettings>();
            }

            return settingsFile;
        }

        public string ToJson()
        {
            var settings = new JsonSerializerSettings()
            {
                Formatting = Formatting.Indented,
                DefaultValueHandling = DefaultValueHandling.Ignore,
                ContractResolver = new CamelCasePropertyNamesContractResolver(),
            };

            settings.Converters.Add(new StringEnumConverter(new CamelCaseNamingStrategy(), false));

            var json = JsonConvert.SerializeObject(this, settings);
            return json;
        }

        public void Write(string path)
        {
            var contents = ToJson();
            File.WriteAllText(path, contents, Encoding.UTF8);
        }

        public EntitySettings GetEntitySettingsOrDefault(string name)
        {
            var wildcardEntity = Entities.FirstOrDefault(e => e.Entity == "*");

            var namedEntity = Entities.FirstOrDefault(e => e.Entity == name);

            var entitySettings = new EntitySettings(name);
            entitySettings.Inherit(namedEntity);
            entitySettings.Inherit(wildcardEntity);

            return entitySettings;
        }

        public FieldSettings GetFieldSettingsOrDefault(string entityName, string fieldName)
        {
            var wildcardEntity = Entities.FirstOrDefault(e => e.Entity == "*");

            var wildcardEntityWildcardField = wildcardEntity?.Fields?.FirstOrDefault(f => f.Field == "*");

            var wildcardEntityNamedField = wildcardEntity?.Fields?.FirstOrDefault(f => f.Field == fieldName);

            var namedEntity = Entities.FirstOrDefault(e => e.Entity == entityName);

            var namedEntityWildcardField = namedEntity?.Fields?.FirstOrDefault(f => f.Field == "*");

            var namedEntityNamedField = namedEntity?.Fields?.FirstOrDefault(f => f.Field == fieldName);

            var fieldSettings = new FieldSettings(fieldName);

            fieldSettings.Inherit(namedEntityNamedField);
            fieldSettings.Inherit(namedEntityWildcardField);
            fieldSettings.Inherit(wildcardEntityNamedField);
            fieldSettings.Inherit(wildcardEntityWildcardField);

            return fieldSettings;
        }
    }
}
