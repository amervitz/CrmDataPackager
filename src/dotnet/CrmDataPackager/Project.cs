using System.Reflection;

namespace CrmDataPackager
{
    public class Project
    {      
        public static string Version => typeof(Project).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>().InformationalVersion;
    }
}
