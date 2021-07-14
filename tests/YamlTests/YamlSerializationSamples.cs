using System;
using System.Collections.Generic;
using Xunit;
using Xunit.Abstractions;
using YamlDotNet.Serialization;

namespace YamlTests
{
    public class YamlSerializationSamples
    {
        private readonly ITestOutputHelper output;

        public YamlSerializationSamples(ITestOutputHelper output)
        {
            this.output = output;
        }

        [Fact]
        public void DictionaryTest()
        {
            var dict = new Dictionary<string, object>();
            dict["id"] = "text";
            dict["age"] = 10;
            dict["weight"] = 55;

            var serializer = new Serializer();
            var yaml = serializer.Serialize(dict);
            output.WriteLine(yaml);
        }

        [Fact]
        public void NestedDictionaryTest()
        {
            var collection = new List<Dictionary<string, object>>
            {
                new Dictionary<string, object>
                {
                    ["id"] = "text",
                    ["age"] = 10,
                    ["weight"] = 55
                },
                new Dictionary<string, object>
                {
                    ["id"] = "seconnd",
                    ["age"] = 14,
                    ["weight"] = 15,
                    ["location"] = "Earth"
                }
            };

            var serializer = new Serializer();
            var yaml = serializer.Serialize(collection);
            output.WriteLine(yaml);
        }
    }
}
