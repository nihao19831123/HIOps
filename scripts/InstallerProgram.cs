using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace HIOps.Installer
{
    class Program
    {
        [STAThread]
        static int Main(string[] args)
        {
            bool isSilent = false;
            bool isUninstall = false;

            foreach (var arg in args)
            {
                string a = arg.Trim().ToLowerInvariant();
                if (a == "/s" || a == "-s" || a == "/silent" || a == "/quiet" || a == "-silent" || a == "-quiet" || a == "/qn")
                {
                    isSilent = true;
                }
                if (a == "/u" || a == "-u" || a == "/uninstall" || a == "-uninstall")
                {
                    isUninstall = true;
                }
            }

            try
            {
                if (isUninstall)
                {
                    return PerformUninstall(isSilent);
                }
                else
                {
                    return PerformInstall(isSilent);
                }
            }
            catch (Exception ex)
            {
                if (!isSilent)
                {
                    MessageBox.Show("安装失败: " + ex.Message, "HIOps 安装错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                return 1;
            }
        }

        static int PerformInstall(bool isSilent)
        {
            string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string targetDir = Path.Combine(programFiles, @"HIOps\Sensor");
            string targetExe = Path.Combine(targetDir, "HIOps.EndpointSensor.exe");

            string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            string spoolDir = Path.Combine(programData, @"HIOps\spool");

            if (!Directory.Exists(targetDir))
            {
                Directory.CreateDirectory(targetDir);
            }
            if (!Directory.Exists(spoolDir))
            {
                Directory.CreateDirectory(spoolDir);
            }

            // 从内嵌资源提取 HIOps.EndpointSensor.exe
            var asm = Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream("SensorPayload"))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("未找到内嵌探针二进制资源。");
                }
                byte[] buffer = new byte[stream.Length];
                stream.Read(buffer, 0, buffer.Length);
                File.WriteAllBytes(targetExe, buffer);
            }

            // 写入或更新 config.ini 配置文件
            string targetConfig = Path.Combine(targetDir, "config.ini");
            if (!File.Exists(targetConfig))
            {
                using (var cstream = asm.GetManifestResourceStream("ConfigPayload"))
                {
                    if (cstream != null)
                    {
                        byte[] cbuf = new byte[cstream.Length];
                        cstream.Read(cbuf, 0, cbuf.Length);
                        File.WriteAllBytes(targetConfig, cbuf);
                    }
                    else
                    {
                        string defaultIni = "# HIOps Client Configuration\r\nServerUrl=http://192.168.114.30:5080\r\nAgentKey=hiops_3a2f5033c247fb06d2c8867fee93205fe46bd416d44c1d42d9f3fc2aa2aadaae\r\nHeartbeatSeconds=30\r\n";
                        File.WriteAllText(targetConfig, defaultIni);
                    }
                }
            }

            // 注册开机自启动计划任务 (schtasks)
            var psi = new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = string.Format("/create /tn \"HIOps_Endpoint_Sensor\" /tr \"\\\"{0}\\\"\" /sc onlogon /rl highest /f", targetExe),
                CreateNoWindow = true,
                UseShellExecute = false,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            var proc = Process.Start(psi);
            if (proc != null) proc.WaitForExit(5000);

            // 启动探针进程
            try
            {
                Process.Start(targetExe);
            }
            catch { }

            if (!isSilent)
            {
                MessageBox.Show(
                    "HIOps 医院智能终端看护探针已成功安装并启动！\n\n• 任务栏右下角已加载运维小助手。\n• 客户端遇假死、卡顿或闪退将自动感知并上报信息中心。",
                    "HIOps 探针安装成功",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }

            return 0;
        }

        static int PerformUninstall(bool isSilent)
        {
            // 杀死正在运行的探针
            foreach (var p in Process.GetProcessesByName("HIOps.EndpointSensor"))
            {
                try { p.Kill(); } catch { }
            }

            // 删除开机计划任务
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "schtasks.exe",
                    Arguments = "/delete /tn \"HIOps_Endpoint_Sensor\" /f",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                var proc = Process.Start(psi);
                if (proc != null) proc.WaitForExit(5000);
            }
            catch { }

            // 删除安装目录
            try
            {
                string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                string targetDir = Path.Combine(programFiles, "HIOps");
                if (Directory.Exists(targetDir)) Directory.Delete(targetDir, true);
            }
            catch { }

            if (!isSilent)
            {
                MessageBox.Show("HIOps 终端看护探针已完全卸载并清理完毕。", "HIOps 卸载完成", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }

            return 0;
        }
    }
}
