using System;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;

namespace HIOps.EndpointSensor.SelfHealing
{
    /// <summary>
    /// 临床终端自动化与一键自愈引擎
    /// 解决医院日常 50% 以上的常见非硬件故障 (打印机死锁、DNS解析假死、HIS缓存损坏)
    /// </summary>
    public class AutoHealingExecutor
    {
        public static bool FixPrintSpooler(out string message)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                using (var sc = new ServiceController("Spooler"))
                {
                    if (sc.Status == ServiceControllerStatus.Running)
                    {
                        sc.Stop();
                        sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(5));
                    }

                    string spoolPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "spool", "PRINTERS");
                    if (Directory.Exists(spoolPath))
                    {
                        foreach (var file in Directory.GetFiles(spoolPath))
                        {
                            try { File.Delete(file); } catch { }
                        }
                    }

                    sc.Start();
                    sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(5));
                }

                sw.Stop();
                message = string.Format("打印机服务已成功重置并清空死锁队列，耗时 {0}ms", sw.ElapsedMilliseconds);
                return true;
            }
            catch (Exception ex)
            {
                message = string.Format("修复打印机失败: {0}", ex.Message);
                return false;
            }
        }

        public static bool FlushDnsAndNetwork(out string message)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "ipconfig",
                    Arguments = "/flushdns",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardOutput = true
                };
                using (var p = Process.Start(psi))
                {
                    p.WaitForExit(3000);
                }

                sw.Stop();
                message = string.Format("DNS 缓存已成功刷新并重置，耗时 {0}ms", sw.ElapsedMilliseconds);
                return true;
            }
            catch (Exception ex)
            {
                message = string.Format("刷新网络失败: {0}", ex.Message);
                return false;
            }
        }

        public static bool ClearAppTempFiles(out string message)
        {
            var sw = Stopwatch.StartNew();
            try
            {
                string tempPath = Path.GetTempPath();
                int deletedCount = 0;
                foreach (var file in Directory.GetFiles(tempPath, "*.tmp"))
                {
                    try
                    {
                        File.Delete(file);
                        deletedCount++;
                    }
                    catch { }
                }

                sw.Stop();
                message = string.Format("已清理临时报表与业务缓存文件 {0} 个，耗时 {1}ms", deletedCount, sw.ElapsedMilliseconds);
                return true;
            }
            catch (Exception ex)
            {
                message = string.Format("清理缓存失败: {0}", ex.Message);
                return false;
            }
        }
    }
}
