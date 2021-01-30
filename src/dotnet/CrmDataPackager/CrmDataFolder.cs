using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using System;
using System.IO;
using System.IO.Compression;

namespace CrmDataPackager
{
    public class CrmDataFolder
    {
        public string FolderPath { get; set; }
        public string DataPath { get; internal set; }
        public string SchemaPath { get; internal set; }
        public string SettingsPath { get; set; }

        private readonly ILogger _logger;

        public CrmDataFolder()
        {
        }

        public CrmDataFolder(string path, ILogger logger = null)
        {
            FolderPath = path;
            _logger = logger ?? NullLogger.Instance;

            DataPath = Path.Combine(path, "data.xml");
            SchemaPath = Path.Combine(path, "data_schema.xml");
            SettingsPath = Path.Combine(path, "settings.json");
        }

        public CrmDataFile Pack(string targetPath)
        {
            string packedPath;
            // when the target is a zip file, pack the contents to a temporary folder, then delete the temporary folder when done
            if (Path.GetExtension(targetPath) == ".zip")
            {
                packedPath = Path.Combine(Path.GetDirectoryName(targetPath), Path.GetFileNameWithoutExtension(targetPath)) + DateTime.Now.ToString("-yyyy-mm-dd-HHmmss");
                _logger.LogTrace($"Creating temporary folder {packedPath}");
            }
            else
            {
                packedPath = targetPath;
                _logger.LogTrace($"Creating folder {packedPath}");
            }

            Directory.CreateDirectory(packedPath);

            var packager = new CrmDataFolderPacker(_logger);
            var crmDataFile = packager.Pack(FolderPath, packedPath);

            // when target is a zip file, create the zip file, then delete the temporary folder
            if (Path.GetExtension(targetPath) == ".zip")
            {
                CreateArchive(packedPath, targetPath);
                _logger.LogTrace($"Deleting temporary folder {packedPath}");
                Directory.Delete(packedPath, true);

                crmDataFile.FilePath = targetPath;
            }

            return crmDataFile;
        }

        private void CreateArchive(string sourceDirectoryName, string destinationArchiveFileName)
        {
            if (File.Exists(destinationArchiveFileName))
            {
                _logger.LogTrace($"Deleting existing file {destinationArchiveFileName}");
                File.Delete(destinationArchiveFileName);
            }

            _logger.LogTrace($"Writing file {destinationArchiveFileName}");
            ZipFile.CreateFromDirectory(sourceDirectoryName, destinationArchiveFileName);
        }
    }
}
