using System;
using System.Diagnostics.Eventing.Reader;
using System.Security.Cryptography;
using System.Text;

namespace HIOps.EndpointSensor.Watchdogs
{
    /// <summary>
    /// 系统级崩溃监听器 (挂接 Windows Application EventLog)
    /// 秒级捕获 Event ID 1000/1001 (Application Error) 与 1026 (.NET Runtime)
    /// </summary>
    public class CrashEventLogWatcher : IDisposable
    {
        private EventLogWatcher _watcher;

        public class CrashInfo
        {
            public string ProcessName { get; set; }
            public string FaultingModule { get; set; }
            public string ExceptionCode { get; set; }
            public string FingerprintHash { get; set; }
            public string RawMessage { get; set; }
        }

        public event Action<CrashInfo> OnCrashCaptured;

        public void Start()
        {
            try
            {
                string queryStr = "*[System[(EventID=1000 or EventID=1001 or EventID=1026)]]";
                var query = new EventLogQuery("Application", PathType.LogName, queryStr);
                _watcher = new EventLogWatcher(query);
                _watcher.EventRecordWritten += Watcher_EventRecordWritten;
                _watcher.Enabled = true;
            }
            catch (Exception ex)
            {
                DebugLog(string.Format("EventLogWatcher start error: {0}", ex.Message));
            }
        }

        private void Watcher_EventRecordWritten(object sender, EventRecordWrittenEventArgs e)
        {
            if (e.EventRecord == null) return;
            try
            {
                string desc = e.EventRecord.FormatDescription();
                var info = ParseCrashDescription(desc);
                if (info != null)
                {
                    info.FingerprintHash = ComputeFingerprint(info.ProcessName, info.FaultingModule, info.ExceptionCode);
                    if (OnCrashCaptured != null)
                    {
                        OnCrashCaptured(info);
                    }
                }
            }
            catch
            {
            }
        }

        public static CrashInfo ParseCrashDescription(string desc)
        {
            if (string.IsNullOrEmpty(desc)) return null;

            var info = new CrashInfo();
            info.RawMessage = desc;
            string[] lines = desc.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries);

            foreach (var line in lines)
            {
                if (line.Contains("Faulting application name:") || line.Contains("错误应用程序名称:"))
                    info.ProcessName = ExtractValue(line);
                else if (line.Contains("Faulting module name:") || line.Contains("错误模块名称:"))
                    info.FaultingModule = ExtractValue(line);
                else if (line.Contains("Exception code:") || line.Contains("异常代码:"))
                    info.ExceptionCode = ExtractValue(line);
            }

            return info;
        }

        public static string ComputeFingerprint(string process, string module, string code)
        {
            string p = (process != null) ? process.ToLowerInvariant() : "";
            string m = (module != null) ? module.ToLowerInvariant() : "";
            string c = (code != null) ? code.ToLowerInvariant() : "";
            string raw = string.Format("{0}|{1}|{2}", p, m, c);

            using (var sha = SHA1.Create())
            {
                byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(raw));
                var sb = new StringBuilder();
                foreach (byte b in hash) sb.Append(b.ToString("X2"));
                return sb.ToString();
            }
        }

        private static string ExtractValue(string line)
        {
            int idx = line.IndexOf(':');
            return idx >= 0 && idx < line.Length - 1 ? line.Substring(idx + 1).Trim().Split(' ')[0] : "unknown";
        }

        private void DebugLog(string msg)
        {
            Console.WriteLine(string.Format("[CrashWatcher] {0}", msg));
        }

        public void Dispose()
        {
            if (_watcher != null)
            {
                _watcher.Dispose();
            }
        }
    }
}
