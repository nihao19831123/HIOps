using System;
using System.Threading;
using System.Windows.Forms;
using HIOps.EndpointSensor.Core;
using HIOps.EndpointSensor.UI;
using HIOps.EndpointSensor.Watchdogs;

namespace HIOps.EndpointSensor
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            // 防止多开 (单实例互斥体)
            bool createdNew;
            using (var mutex = new Mutex(true, "Global\\HIOps_Endpoint_Sensor_Mutex", out createdNew))
            {
                if (!createdNew)
                {
                    return; // 已有实例在运行，静默退出
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                // 初始化核心组件
                var ringBuffer = new ActionTrailRingBuffer(capacity: 50);
                var netProbe = new SyntheticNetProbe();
                var spooler = new OfflineSpooler();
                var orchestrator = new ForensicOrchestrator(ringBuffer, netProbe, spooler);

                // 启动 UI Hang 看门狗定时器 (每 3 秒检查一次)
                var hangWatchdog = new UiHangWatchdogWorker();
                hangWatchdog.OnHangDetected += (proc, hWnd, title, duration) =>
                {
                    orchestrator.CaptureAndDispatchAsync("UI_HANG", proc, hWnd, null, duration, null);
                };

                var watchdogTimer = new System.Windows.Forms.Timer();
                watchdogTimer.Interval = 3000;
                watchdogTimer.Tick += (s, e) => hangWatchdog.CheckAllTargets();
                watchdogTimer.Start();

                // 启动崩溃监听器
                var crashWatcher = new CrashEventLogWatcher();
                crashWatcher.OnCrashCaptured += (info) =>
                {
                    orchestrator.CaptureAndDispatchAsync("CRASH_WER", null, IntPtr.Zero, info.RawMessage, 0, null);
                };
                crashWatcher.Start();

                // 启动桌面小助手托盘
                using (var tray = new SysTrayCompanion())
                {
                    tray.OnUserRequestedForensics += () =>
                    {
                        orchestrator.CaptureAndDispatchAsync("MANUAL_HOTKEY");
                    };

                    Application.Run();
                }

                crashWatcher.Dispose();
            }
        }
    }
}
