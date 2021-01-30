using Microsoft.Extensions.Logging;
using System;

namespace CrmDataPackager
{
    public class PowerShellLogger : ILogger
    {
        public Action<string> TraceLogger;
        public Action<string> DebugLogger;
        public Action<string> ErrorLogger;
        public Action<string> InformationLogger;

        public bool IsEnabled(LogLevel logLevel)
        {
            switch (logLevel)
            {
                case LogLevel.Trace:
                    return TraceLogger != null;
                case LogLevel.Debug:
                    return DebugLogger != null;
                case LogLevel.Error:
                    return ErrorLogger != null;
                case LogLevel.Information:
                    return InformationLogger != null;
                default:
                    return false;
            }
        }

        public IDisposable BeginScope<TState>(TState state) => default;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter)
        {
            switch (logLevel)
            {
                case LogLevel.Trace:
                    TraceLogger?.Invoke(formatter(state, exception));
                    break;
                case LogLevel.Debug:
                    DebugLogger?.Invoke(formatter(state, exception));
                    break;
                case LogLevel.Error:
                    ErrorLogger?.Invoke(formatter(state, exception));
                    break;
                case LogLevel.Information:
                    InformationLogger?.Invoke(formatter(state, exception));
                    break;
                default:
                    break;
            }
        }
    }
}
