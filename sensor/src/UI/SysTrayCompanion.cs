using System;
using System.Drawing;
using System.Windows.Forms;
using HIOps.EndpointSensor.SelfHealing;

namespace HIOps.EndpointSensor.UI
{
    /// <summary>
    /// 桌面运维小助手 (Windows 任务栏托盘交互组件)
    /// 绿色=正常，黄色=网络抖动，红色=核心异常
    /// </summary>
    public class SysTrayCompanion : IDisposable
    {
        private readonly NotifyIcon _trayIcon;
        private readonly ContextMenuStrip _contextMenu;

        public event Action OnUserRequestedForensics;

        public SysTrayCompanion()
        {
            _contextMenu = new ContextMenuStrip();
            
            var statusItem = new ToolStripMenuItem("当前状态: 🟢 核心业务畅通 (延迟 1.2ms)");
            statusItem.Enabled = false;

            var healPrintItem = new ToolStripMenuItem("一键修复打印机", null, OnHealPrintClicked);
            var healDnsItem = new ToolStripMenuItem("一键重置网络与DNS", null, OnHealDnsClicked);
            var healTempItem = new ToolStripMenuItem("一键清除业务临时缓存", null, OnHealTempClicked);
            var reportItem = new ToolStripMenuItem("📸 一键诊断并留证报修 (Ctrl+Alt+H)", null, OnReportClicked);
            var sep = new ToolStripSeparator();
            var aboutItem = new ToolStripMenuItem("关于 HIOps 医院运维助手 v2.0", null, OnAboutClicked);

            _contextMenu.Items.Add(statusItem);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(healPrintItem);
            _contextMenu.Items.Add(healDnsItem);
            _contextMenu.Items.Add(healTempItem);
            _contextMenu.Items.Add(new ToolStripSeparator());
            _contextMenu.Items.Add(reportItem);
            _contextMenu.Items.Add(sep);
            _contextMenu.Items.Add(aboutItem);

            _trayIcon = new NotifyIcon();
            _trayIcon.Icon = SystemIcons.Shield;
            _trayIcon.ContextMenuStrip = _contextMenu;
            _trayIcon.Text = "HIOps 医院信息运维助手";
            _trayIcon.Visible = true;
        }

        private void OnHealPrintClicked(object sender, EventArgs e)
        {
            string msg;
            if (AutoHealingExecutor.FixPrintSpooler(out msg))
                ShowBalloon("修复完成", msg, ToolTipIcon.Info);
            else
                ShowBalloon("修复失败", msg, ToolTipIcon.Error);
        }

        private void OnHealDnsClicked(object sender, EventArgs e)
        {
            string msg;
            if (AutoHealingExecutor.FlushDnsAndNetwork(out msg))
                ShowBalloon("重置成功", msg, ToolTipIcon.Info);
        }

        private void OnHealTempClicked(object sender, EventArgs e)
        {
            string msg;
            if (AutoHealingExecutor.ClearAppTempFiles(out msg))
                ShowBalloon("清理完成", msg, ToolTipIcon.Info);
        }

        private void OnReportClicked(object sender, EventArgs e)
        {
            if (OnUserRequestedForensics != null)
            {
                OnUserRequestedForensics();
            }
            ShowBalloon("已留存现场", "系统已自动捕获当前报错现场并直发信息中心，工程师已介入处理！", ToolTipIcon.Info);
        }

        private void OnAboutClicked(object sender, EventArgs e)
        {
            MessageBox.Show("HIOps 医院智能信息运维平台 — 终端看护卫士\n版本: v2.0 (生产实战版)\n信息中心技术支持", "HIOps", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        public void UpdateStatus(string text, Color statusColor)
        {
            if (_contextMenu.Items.Count > 0)
            {
                _contextMenu.Items[0].Text = text;
            }
        }

        public void ShowBalloon(string title, string content, ToolTipIcon icon)
        {
            _trayIcon.ShowBalloonTip(3000, title, content, icon);
        }

        public void Dispose()
        {
            if (_trayIcon != null) _trayIcon.Dispose();
            if (_contextMenu != null) _contextMenu.Dispose();
        }
    }
}
