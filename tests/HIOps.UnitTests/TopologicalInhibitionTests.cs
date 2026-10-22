using System;
using System.Collections.Generic;
using System.Linq;
using Xunit;
using HIOps.Core.Engines;
using HIOps.Core.Models;

namespace HIOps.UnitTests
{
    public class TopologicalInhibitionTests
    {
        [Fact]
        public void Engine_ShouldSuppressChildAlerts_WhenParentIsDown()
        {
            // Arrange (UT-08)
            var engine = new TopologicalInhibitionEngine();

            var events = new List<IncidentEvent>
            {
                // 父级核心交换机故障
                new IncidentEvent
                {
                    Id = Guid.NewGuid(),
                    SourceAssetName = "SW-MZ-2F",
                    SegmentPrefix = "192.168.20.",
                    EventType = "SWITCH_DOWN",
                    IsSuppressed = false
                },
                // 挂接在下方的 3 台终端报网络超时
                new IncidentEvent
                {
                    Id = Guid.NewGuid(),
                    SourceAssetName = "MZ-PC-01",
                    SegmentPrefix = "192.168.20.",
                    EventType = "TERMINAL_TIMEOUT",
                    IsSuppressed = false
                },
                new IncidentEvent
                {
                    Id = Guid.NewGuid(),
                    SourceAssetName = "MZ-PC-02",
                    SegmentPrefix = "192.168.20.",
                    EventType = "TERMINAL_TIMEOUT",
                    IsSuppressed = false
                },
                // 另一个未受影响网段的终端
                new IncidentEvent
                {
                    Id = Guid.NewGuid(),
                    SourceAssetName = "ZY-PC-01",
                    SegmentPrefix = "192.168.30.",
                    EventType = "TERMINAL_TIMEOUT",
                    IsSuppressed = false
                }
            };

            // Act
            engine.ApplyInhibition(events);

            // Assert
            var p1 = events.First(e => e.SourceAssetName == "MZ-PC-01");
            var p2 = events.First(e => e.SourceAssetName == "MZ-PC-02");
            var p3 = events.First(e => e.SourceAssetName == "ZY-PC-01");

            Assert.True(p1.IsSuppressed);
            Assert.Contains("SW-MZ-2F", p1.SuppressReason);
            Assert.True(p2.IsSuppressed);
            Assert.False(p3.IsSuppressed); // 不同网段不受抑制
        }
    }
}
