using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using System.IO;
using System.IO.Compression;

namespace CrmDataPackager
{
    public class CrmDataFile
    {        
        private readonly ILogger _logger;
        public string FilePath { get; set; }

        public CrmDataFile()
        {
        }

        public CrmDataFile(string path, ILogger logger = null)
        {
            FilePath = path;
            _logger = logger ?? NullLogger.Instance;
        }

        public CrmDataFolder Extract(string targetPath, string settingsFilePath)
        {
            if (IsArchive(FilePath))
            {
                ExtractArchive(FilePath, targetPath);
            }
            else if(IsDirectory(FilePath) && FilePath != targetPath)
            {
                CopyFolder(FilePath, targetPath);
            }

            var packager = new CrmDataFileExtractor(_logger);
            var crmDataFolder = packager.Extract(targetPath, settingsFilePath);
            return crmDataFolder;
        }

        private void ExtractArchive(string sourceArchiveFileName, string destinationDirectoryName)
        {
            if (Directory.Exists(destinationDirectoryName))
            {
                _logger.LogTrace($"Deleting existing folder {destinationDirectoryName}");
                Directory.Delete(destinationDirectoryName, true);
            }

            _logger.LogTrace($"Extracting zip file to folder {destinationDirectoryName}");
            ZipFile.ExtractToDirectory(sourceArchiveFileName, destinationDirectoryName);
        }

        private void CopyFolder(string sourcePath, string targetPath)
        {
            if (Directory.Exists(targetPath))
            {
                _logger.LogTrace($"Deleting existing folder {targetPath}");
                Directory.Delete(targetPath, true);
            }

            _logger.LogTrace($"Copying source folder to folder {targetPath}");
            DirectoryExtensions.DirectoryCopy(sourcePath, targetPath, true);
        }

        private bool IsArchive(string path)
        {
            var file = new FileInfo(path);
            return file.Exists && file.Extension == ".zip";
        }
        
        private bool IsDirectory(string path)
        {
            var folder = new DirectoryInfo(path);
            return folder.Exists;
        }
    }
}
