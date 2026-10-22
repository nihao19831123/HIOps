using System;
using System.Collections.Generic;

namespace HIOps.EndpointSensor.Models
{
    public class ForensicPackage
    {
        public string FingerprintHash { get; set; }
        public string AssetCode { get; set; }
        public string HostName { get; set; }
        public string IpAddress { get; set; }
        public DateTime OccurredAt { get; set; }
        public string TriggerType { get; set; } // UI_HANG, CRASH_WER, MANUAL_HOTKEY
        public int HangDurationMs { get; set; }
        public string ActiveWindowTitle { get; set; }
        public string OcrErrorText { get; set; }
        public string StackTrace { get; set; }
        public List<ActionEntry> ActionTrail { get; set; }
        public List<NetProbeResult> NetProbes { get; set; }
        public string ScreenshotThumbBase64 { get; set; }

        public ForensicPackage()
        {
            OccurredAt = DateTime.UtcNow;
            ActionTrail = new List<ActionEntry>();
            NetProbes = new List<NetProbeResult>();
        }
    }

    public class NetProbeResult
    {
        public string TargetService { get; set; }
        public double RttMs { get; set; }
        public double LossRate { get; set; }
    }
}
