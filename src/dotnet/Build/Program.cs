using System.IO;
using CrmDataPackager;
using Microsoft.Extensions.Logging;

namespace Build
{
    class Program
    {
        static void Main(string[] args)
        {
            string command = args[0];

            ILoggerFactory loggerFactory = LoggerFactory.Create(builder =>
            {
                builder.AddConsole();
            });

            ILogger<Program> logger = loggerFactory.CreateLogger<Program>();

            if (command == "extract")
            {
                string zipFile = args[1];
                string folder = args[2];

                string path = Path.GetFullPath(zipFile);
                string targetPath = Path.GetFullPath(folder);

                string settingsFilePath = args.Length >= 4 ? args[3] : @"C:\temp\CrmDataPackagerSettings-wildcard.min.json";

                CrmDataFile crmDataFile = new CrmDataFile(path, logger);
                crmDataFile.Extract(targetPath, settingsFilePath);
            }
            else if (command == "pack")
            {
                string folder = args[1];
                string zipFile = args[2];

                string path = Path.GetFullPath(zipFile);
                string targetPath = Path.GetFullPath(folder);

                CrmDataFolder crmDataFolder = new CrmDataFolder(path, logger);
                crmDataFolder.Pack(targetPath);
            }
        }
    }
}