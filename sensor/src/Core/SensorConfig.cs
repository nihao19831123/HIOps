using System;
using System.IO;

namespace HIOps.EndpointSensor.Core
{
    public static class SensorConfig
    {
        public static string ServerUrl { get; set; }
        public static string AgentKey { get; set; }
        public static string AgentVersion { get; set; }
        public static int HeartbeatIntervalSeconds { get; set; }

        static SensorConfig()
        {
            ServerUrl = "http://192.168.114.30:5080";
            AgentKey = "hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae";
            AgentVersion = "2.0.1";
            HeartbeatIntervalSeconds = 30;
        }

        public static void Init(string[] args)
        {
            // 1. 尝试从本目录或 ProgramData 读取 config.ini / HIOps.ini
            string appDir = AppDomain.CurrentDomain.BaseDirectory;
            string localIni = Path.Combine(appDir, "config.ini");
            string commonIni = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "HIOps", "config.ini");

            string targetIni = File.Exists(localIni) ? localIni : (File.Exists(commonIni) ? commonIni : null);
            if (targetIni != null)
            {
                LoadFromIni(targetIni);
            }

            // 2. 命令行参数覆盖 (如: HIOps.EndpointSensor.exe --server http://192.168.114.30:5080 --key <key>)
            if (args != null)
            {
                for (int i = 0; i < args.Length; i++)
                {
                    if (string.Equals(args[i], "--server", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    {
                        ServerUrl = args[i + 1].TrimEnd('/');
                    }
                    else if (string.Equals(args[i], "--key", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    {
                        AgentKey = args[i + 1].Trim();
                    }
                }
            }
        }

        private static void LoadFromIni(string path)
        {
            try
            {
                var lines = File.ReadAllLines(path);
                foreach (var rawLine in lines)
                {
                    var line = rawLine.Trim();
                    if (string.IsNullOrEmpty(line) || line.StartsWith("#") || line.StartsWith(";"))
                        continue;

                    int eqIdx = line.IndexOf('=');
                    if (eqIdx > 0)
                    {
                        string k = line.Substring(0, eqIdx).Trim().ToLowerInvariant();
                        string v = line.Substring(eqIdx + 1).Trim();

                        if (k == "serverurl" || k == "server" || k == "host")
                        {
                            ServerUrl = v.TrimEnd('/');
                        }
                        else if (k == "agentkey" || k == "key" || k == "token")
                        {
                            AgentKey = v;
                        }
                        else if (k == "heartbeatseconds" || k == "interval")
                        {
                            int sec;
                            if (int.TryParse(v, out sec) && sec >= 5)
                            {
                                HeartbeatIntervalSeconds = sec;
                            }
                        }
                    }
                }
            }
            catch { }
        }
    }
}
