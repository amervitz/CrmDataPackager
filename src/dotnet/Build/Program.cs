using Microsoft.Extensions.Logging;
using System.IO;

namespace Build
{
    class Program
    {
        static void Main(string[] args)
        {
            var zipFile = args[0];
            var folder = args[1];
            var settingsFilePath = @"D:\Repos\CrmDataPackager\src\pwsh\CrmDataPackager\settings.json";

            var path = Path.GetFullPath(zipFile);
            var targetPath = Path.GetFullPath(folder);

            var loggerFactory = LoggerFactory.Create(builder =>
            {
                builder.AddConsole();
            });

            var logger = loggerFactory.CreateLogger<Program>();

            var crmDataFile = new CrmDataPackager.CrmDataFile(path, logger);
            crmDataFile.Extract(targetPath, settingsFilePath);
        }
    }
}
