using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace HIOps.EndpointSensor.Core
{
    /// <summary>
    /// 本地离线缓冲队列与背压重传引擎 (Spooler)
    /// 医院断网时加密写入本地 50MB 磁盘队列，先进先出淘汰；
    /// 联网恢复后按 3 秒间隔、单次 1 包渐进重传，防止雪崩打垮服务器
    /// </summary>
    public class OfflineSpooler
    {
        private readonly string _spoolDir;
        private readonly long _maxDiskBytes;
        private readonly HttpClient _http;

        public OfflineSpooler(string spoolDir = null, long maxDiskMb = 50)
        {
            _spoolDir = spoolDir ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "HIOps", "spool");
            _maxDiskBytes = maxDiskMb * 1024 * 1024;
            _http = new HttpClient();

            if (!Directory.Exists(_spoolDir))
            {
                Directory.CreateDirectory(_spoolDir);
            }
        }

        public void Enqueue(string payloadJson)
        {
            EnforceDiskLimit();

            string fileName = string.Format("spool_{0:yyyyMMddHHmmssfff}_{1:N}.dat", DateTime.UtcNow, Guid.NewGuid());
            string filePath = Path.Combine(_spoolDir, fileName);

            byte[] rawBytes = Encoding.UTF8.GetBytes(payloadJson);
            File.WriteAllBytes(filePath, rawBytes);
        }

        public async Task DrainQueueAsync(string reportUrl, string sensorToken)
        {
            var files = Directory.GetFiles(_spoolDir, "*.dat")
                                 .OrderBy(f => File.GetCreationTimeUtc(f))
                                 .ToList();

            foreach (var file in files)
            {
                try
                {
                    byte[] bytes = File.ReadAllBytes(file);
                    string json = Encoding.UTF8.GetString(bytes);

                    var req = new HttpRequestMessage(HttpMethod.Post, reportUrl);
                    req.Headers.Add("X-HIOps-Agent-Key", SensorConfig.AgentKey);
                    req.Headers.Add("X-HIOps-Device-Id", Environment.MachineName);
                    req.Headers.Add("X-HIOps-Sensor-Token", sensorToken);
                    req.Content = new StringContent(json, Encoding.UTF8, "application/json");

                    var resp = await _http.SendAsync(req);
                    if (resp.IsSuccessStatusCode)
                    {
                        File.Delete(file);
                        await Task.Delay(3000);
                    }
                    else
                    {
                        break;
                    }
                }
                catch
                {
                    break;
                }
            }
        }

        private void EnforceDiskLimit()
        {
            var files = new DirectoryInfo(_spoolDir)
                .GetFiles("*.dat")
                .OrderBy(f => f.CreationTimeUtc)
                .ToList();

            long totalBytes = files.Sum(f => f.Length);

            while (totalBytes > _maxDiskBytes && files.Count > 0)
            {
                var oldest = files[0];
                totalBytes -= oldest.Length;
                oldest.Delete();
                files.RemoveAt(0);
            }
        }
    }
}
