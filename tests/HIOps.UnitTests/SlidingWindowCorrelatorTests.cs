using System;
using System.Linq;
using Xunit;
using HIOps.Core.Engines;
using HIOps.Core.Models;

namespace HIOps.UnitTests
{
    public class SlidingWindowCorrelatorTests
    {
        [Fact]
        public void Correlator_ShouldClusterEvents_BySegmentAndSwitch()
        {
            // Arrange (UT-06)
            var correlator = new SlidingWindowCorrelator(windowSeconds: 120);
            var now = DateTime.UtcNow;

            // 传入 3 个同网段 192.168.20. 的超时事件
            correlator.IngestEvent(new IncidentEvent
            {
                SourceAssetName = "PC-MZ-01",
                SegmentPrefix = "192.168.20.",
                EventType = "TERMINAL_TIMEOUT",
                TriggeredAt = now.AddSeconds(-30)
            });
            correlator.IngestEvent(new IncidentEvent
            {
                SourceAssetName = "PC-MZ-02",
                SegmentPrefix = "192.168.20.",
                EventType = "TERMINAL_TIMEOUT",
                TriggeredAt = now.AddSeconds(-20)
            });
            correlator.IngestEvent(new IncidentEvent
            {
                SourceAssetName = "PC-MZ-03",
                SegmentPrefix = "192.168.20.",
                EventType = "TERMINAL_TIMEOUT",
                TriggeredAt = now.AddSeconds(-10)
            });

            // 传入 1 个不同网段的孤立事件
            correlator.IngestEvent(new IncidentEvent
            {
                SourceAssetName = "PC-ZY-01",
                SegmentPrefix = "192.168.30.",
                EventType = "UI_HANG",
                TriggeredAt = now.AddSeconds(-5)
            });

            // Act
            var incidents = correlator.EvaluateAndCorrelate(now);

            // Assert
            Assert.Equal(2, incidents.Count);

            // 检查 P2 事故
            var p2 = incidents.FirstOrDefault(i => i.SeverityLevel == "P2");
            Assert.NotNull(p2);
            Assert.Equal("192.168.20.", p2.DimensionKey);
            Assert.Equal(3, p2.AffectedCount);
            Assert.Equal(2, p2.AutoSuppressedCount); // 自动抑制了 2 个次生报警

            // 检查 P4 孤立单机事故
            var p4 = incidents.FirstOrDefault(i => i.SeverityLevel == "P4");
            Assert.NotNull(p4);
            Assert.Equal("PC-ZY-01", p4.DimensionKey);
        }
    }
}
