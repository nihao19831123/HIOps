using System;
using System.Diagnostics;
using System.Drawing;
using System.Threading.Tasks;
using HIOps.EndpointSensor.Core;
using HIOps.EndpointSensor.Models;
using HIOps.EndpointSensor.Watchdogs;

namespace HIOps.EndpointSensor
{
    /// <summary>
    /// 取证总协调中枢 (Forensic Orchestrator)
    /// 当检测到 UI Hang、Crash 或医护主动按键报障时，执行 0.5s 原子取证并推入上报队列
    /// </summary>
    public class ForensicOrchestrator
    {
        private readonly ActionTrailRingBuffer _actionTrail;
        private readonly SyntheticNetProbe _netProbe;
        private readonly OfflineSpooler _spooler;
        private readonly string _reportUrl;
        private readonly string _sensorToken;

        public ForensicOrchestrator(
            ActionTrailRingBuffer actionTrail, 
            SyntheticNetProbe netProbe, 
            OfflineSpooler spooler,
            string reportUrl = null,
            string sensorToken = null)
        {
            _actionTrail = actionTrail;
            _netProbe = netProbe;
            _spooler = spooler;
            _reportUrl = reportUrl ?? (SensorConfig.ServerUrl.TrimEnd('/') + "/api/v1/sensors/forensics/report");
            _sensorToken = sensorToken ?? SensorConfig.AgentKey;
        }

        public async Task CaptureAndDispatchAsync(
            string triggerType, 
            Process targetProc, 
            IntPtr hWnd, 
            string ocrText, 
            int hangDuration,
            string stackTrace)
        {
            var sw = Stopwatch.StartNew();

            // 1. 冻结内存前序因果时光机 (最近 60s 操作流水)
            var actionTrailSnapshot = _actionTrail.FreezeAndDump();

            // 2. 抓取瞬时网络微探针时延
            var netProbes = await _netProbe.ProbeAllAsync(1500);

            // 3. 截取并脱敏报错窗口图像
            string thumbBase64 = null;
            try
            {
                using (var maskedBmp = PiiMaskingEngine.CaptureAndMaskWindow(hWnd))
                {
                    thumbBase64 = PiiMaskingEngine.ConvertToCompressedBase64(maskedBmp, 640);
                }
            }
            catch
            {
            }

            // 4. 计算指纹
            string procName = (targetProc != null) ? targetProc.ProcessName : "UnknownProcess";
            string fingerprint = CrashEventLogWatcher.ComputeFingerprint(procName, "main_thread", triggerType);

            // 5. 组装确定性复现包
            string stack = stackTrace;
            if (string.IsNullOrEmpty(stack))
            {
                stack = (targetProc != null) ? string.Format("Process: {0}, PID: {1}", targetProc.ProcessName, targetProc.Id) : "N/A";
            }

            var package = new ForensicPackage();
            package.FingerprintHash = fingerprint;
            package.AssetCode = Environment.MachineName + "_SENSOR";
            package.HostName = Environment.MachineName;
            package.IpAddress = GetLocalIpAddress();
            package.OccurredAt = DateTime.UtcNow;
            package.TriggerType = triggerType;
            package.HangDurationMs = hangDuration;
            package.ActiveWindowTitle = (targetProc != null) ? targetProc.MainWindowTitle : "ActiveWindow";
            package.OcrErrorText = (ocrText != null) ? ocrText : "AutoCaptured";
            package.StackTrace = stack;
            package.ActionTrail = actionTrailSnapshot;
            package.NetProbes = netProbes;
            package.ScreenshotThumbBase64 = thumbBase64;

            sw.Stop();

            // 6. 序列化并入本地暂存队列，由后台出站线程重传
            string json = SimpleJsonSerialize(package);
            _spooler.Enqueue(json);

            // 触发立即尝试回传
            Task drainTask = _spooler.DrainQueueAsync(_reportUrl, _sensorToken);
        }

        public Task CaptureAndDispatchAsync(string triggerType)
        {
            return CaptureAndDispatchAsync(triggerType, null, IntPtr.Zero, null, 0, null);
        }

        private static string GetLocalIpAddress()
        {
            try
            {
                var host = System.Net.Dns.GetHostEntry(System.Net.Dns.GetHostName());
                foreach (var ip in host.AddressList)
                {
                    if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork && !System.Net.IPAddress.IsLoopback(ip))
                    {
                        return ip.ToString();
                    }
                }
            }
            catch { }
            return "127.0.0.1";
        }

        private static string SimpleJsonSerialize(ForensicPackage p)
        {
            return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(p);
        }
    }
}
