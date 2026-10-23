using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;
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

            Log("==================================================================");
            Log(string.Format("HIOps 安装程序启动 - 时间: {0:yyyy-MM-dd HH:mm:ss}", DateTime.Now));
            Log(string.Format("操作系统: {0} ({1})", Environment.OSVersion, Environment.Is64BitOperatingSystem ? "64位" : "32位"));
            Log(string.Format("计算机名: {0}, 当前用户: {1}", Environment.MachineName, Environment.UserName));
            Log(string.Format("管理员权限: {0}", IsAdministrator() ? "是" : "否 (非管理员可能安装失败)"));
            Log(string.Format(".NET CLR 运行时版本: {0}", Environment.Version));
            Log(string.Format("命令行参数: {0}", string.Join(" ", args)));
            Log(string.Format("运行模式: {0}, 静默模式: {1}", isUninstall ? "卸载" : "安装", isSilent ? "是" : "否"));

            try
            {
                if (isUninstall)
                {
                    int res = PerformUninstall(isSilent);
                    Log(string.Format("卸载完成，返回值: {0}", res));
                    return res;
                }
                else
                {
                    int res = PerformInstall(isSilent);
                    Log(string.Format("安装完成，返回值: {0}", res));
                    return res;
                }
            }
            catch (Exception ex)
            {
                Log(string.Format("【严重错误】操作失败: {0}\r\n堆栈详情:\r\n{1}", ex.Message, ex.StackTrace));
                if (!isSilent)
                {
                    MessageBox.Show("安装遇到错误，详情已记录到日志文件：\nC:\\ProgramData\\HIOps\\install.log\n\n错误信息: " + ex.Message, "HIOps 安装错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
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

            Log(string.Format("安装目标目录: {0}", targetDir));
            Log(string.Format("离线缓冲目录: {0}", spoolDir));

            if (!Directory.Exists(targetDir))
            {
                Directory.CreateDirectory(targetDir);
                Log("创建安装目标目录成功。");
            }
            if (!Directory.Exists(spoolDir))
            {
                Directory.CreateDirectory(spoolDir);
                Log("创建离线缓冲目录成功。");
            }

            // 1. 关闭正在运行的旧版本探针进程，防止文件占用锁死报错
            Log("检查并关闭可能已运行的旧版本探针进程...");
            foreach (var p in Process.GetProcessesByName("HIOps.EndpointSensor"))
            {
                try
                {
                    Log(string.Format("发现正在运行的旧进程 PID={0}，正在终止...", p.Id));
                    p.Kill();
                    p.WaitForExit(3000);
                    Log("旧进程终止成功。");
                }
                catch (Exception pEx)
                {
                    Log(string.Format("终止进程时发生异常: {0}", pEx.Message));
                }
            }

            // 2. 从内嵌资源提取 HIOps.EndpointSensor.exe
            Log("正在释放探针核心二进制文件...");
            var asm = Assembly.GetExecutingAssembly();
            using (var stream = asm.GetManifestResourceStream("SensorPayload"))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("未找到内嵌探针二进制资源 (SensorPayload)。");
                }
                byte[] buffer = new byte[stream.Length];
                stream.Read(buffer, 0, buffer.Length);
                File.WriteAllBytes(targetExe, buffer);
                Log(string.Format("探针核心写入完成，大小: {0} 字节", buffer.Length));
            }

            // 3. 写入或更新 config.ini 配置文件
            string targetConfig = Path.Combine(targetDir, "config.ini");
            if (!File.Exists(targetConfig))
            {
                Log("目标机尚无 config.ini，释放默认连接配置...");
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
                Log("config.ini 配置文件生成完成。");
            }
            else
            {
                Log("检测到已存在本地 config.ini，保留既有网络配置。");
            }

            // 4. 注册开机自启动计划任务 (schtasks)
            Log("正在通过 schtasks 注册系统级登录自启动看护任务...");
            var psi = new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = string.Format("/create /tn \"HIOps_Endpoint_Sensor\" /tr \"\\\"{0}\\\"\" /sc onlogon /rl highest /f", targetExe),
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };
            var proc = Process.Start(psi);
            if (proc != null)
            {
                string schOut = proc.StandardOutput.ReadToEnd();
                string schErr = proc.StandardError.ReadToEnd();
                proc.WaitForExit(5000);
                Log(string.Format("schtasks 执行结果 (ExitCode={0}): 输出={1}, 错误={2}", proc.ExitCode, schOut.Trim(), schErr.Trim()));
            }

            // 5. 启动探针进程
            Log("正在拉起探针后台常驻服务...");
            try
            {
                var runPsi = new ProcessStartInfo
                {
                    FileName = targetExe,
                    WorkingDirectory = targetDir,
                    UseShellExecute = true
                };
                Process.Start(runPsi);
                Log("探针主进程拉起成功！");
            }
            catch (Exception startEx)
            {
                Log(string.Format("启动探针主进程时告警: {0}", startEx.Message));
            }

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
            Log("开始执行卸载流程...");
            // 杀死正在运行的探针
            foreach (var p in Process.GetProcessesByName("HIOps.EndpointSensor"))
            {
                try
                {
                    Log(string.Format("终止进程 PID={0}...", p.Id));
                    p.Kill();
                    p.WaitForExit(3000);
                }
                catch { }
            }

            // 删除开机计划任务
            try
            {
                Log("正在删除系统自启动看护任务计划...");
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

            // 删除已安装文件
            string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            string targetDir = Path.Combine(programFiles, @"HIOps\Sensor");
            try
            {
                if (Directory.Exists(targetDir))
                {
                    Log(string.Format("删除安装文件目录: {0}", targetDir));
                    Directory.Delete(targetDir, true);
                }
            }
            catch (Exception ex)
            {
                Log(string.Format("清理目录时发生告警: {0}", ex.Message));
            }

            if (!isSilent)
            {
                MessageBox.Show("HIOps 终端看护探针已完全卸载并移除系统服务。", "HIOps 卸载成功", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }

            return 0;
        }

        static bool IsAdministrator()
        {
            try
            {
                var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }

        static void Log(string msg)
        {
            string line = string.Format("[{0:yyyy-MM-dd HH:mm:ss}] {1}\r\n", DateTime.Now, msg);
            try
            {
                string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
                string logDir = Path.Combine(programData, "HIOps");
                if (!Directory.Exists(logDir)) Directory.CreateDirectory(logDir);
                File.AppendAllText(Path.Combine(logDir, "install.log"), line);
            }
            catch { }

            try
            {
                File.AppendAllText(Path.Combine(Path.GetTempPath(), "hiops_install.log"), line);
            }
            catch { }
        }
    }
}
