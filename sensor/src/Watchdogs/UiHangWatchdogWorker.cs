using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace HIOps.EndpointSensor.Watchdogs
{
    /// <summary>
    /// UI Hang 外部非侵入式看门狗
    /// 每 3 秒外部探测白名单进程主窗口，超过 5 秒未响应自动判定卡死
    /// </summary>
    public class UiHangWatchdogWorker
    {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            uint msg,
            IntPtr wParam,
            IntPtr lParam,
            uint fuFlags,
            uint uTimeout,
            out UIntPtr lpdwResult);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool IsHungAppWindow(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        private const uint SMTO_ABORTIFHUNG = 0x0002;
        private const uint WM_NULL = 0x0000;
        private const uint TIMEOUT_MS = 5000;

        private readonly HashSet<string> _targetProcesses;

        public event Action<Process, IntPtr, string, int> OnHangDetected;

        public UiHangWatchdogWorker()
        {
            _targetProcesses = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            _targetProcesses.Add("HIS");
            _targetProcesses.Add("EMR");
            _targetProcesses.Add("LIS");
            _targetProcesses.Add("PACSViewer");
            _targetProcesses.Add("ClinicClient");
        }

        public void CheckAllTargets()
        {
            foreach (var proc in Process.GetProcesses())
            {
                try
                {
                    if (!_targetProcesses.Contains(proc.ProcessName)) continue;
                    IntPtr hWnd = proc.MainWindowHandle;
                    if (hWnd == IntPtr.Zero) continue;

                    var sw = Stopwatch.StartNew();
                    UIntPtr lpdwResult;
                    IntPtr result = SendMessageTimeout(
                        hWnd,
                        WM_NULL,
                        IntPtr.Zero,
                        IntPtr.Zero,
                        SMTO_ABORTIFHUNG,
                        TIMEOUT_MS,
                        out lpdwResult);
                    sw.Stop();

                    if (result == IntPtr.Zero && IsHungAppWindow(hWnd))
                    {
                        var titleSb = new StringBuilder(256);
                        GetWindowText(hWnd, titleSb, 256);
                        string title = titleSb.ToString();

                        if (OnHangDetected != null)
                        {
                            OnHangDetected(proc, hWnd, title, (int)sw.ElapsedMilliseconds);
                        }
                    }
                }
                catch
                {
                }
            }
        }
    }
}
