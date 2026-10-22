using System;
using System.Collections.Generic;
using Xunit;
using HIOps.Core.Engines;
using HIOps.Core.Models;

namespace HIOps.UnitTests
{
    public class PrincipalRcaArbiterTests
    {
        [Fact]
        public void Arbiter_ShouldScoreDatabaseLockHigher_ThanClientHang()
        {
            // Arrange (UT-07)
            var arbiter = new PrincipalRcaArbiter();
            var now = DateTime.UtcNow;

            var events = new List<IncidentEvent>
            {
                // 10:14:05 核心数据库行锁 (早 5 秒发生，深度 1.0)
                new IncidentEvent
                {
                    AssetId = Guid.NewGuid(),
                    SourceAssetName = "HIS-ORACLE-01",
                    EventType = "CORE_DB_LOCK",
                    TopologyDepth = 1.0,
                    TriggeredAt = now.AddSeconds(-5)
                },
                // 10:14:10 终端 HIS 卡死 (从属现象，深度 0.1)
                new IncidentEvent
                {
                    AssetId = Guid.NewGuid(),
                    SourceAssetName = "MZ-PC-021",
                    EventType = "UI_HANG",
                    TopologyDepth = 0.1,
                    TriggeredAt = now
                }
            };

            // Act
            var verdict = arbiter.Arbitrate(events);

            // Assert
            Assert.NotNull(verdict);
            Assert.Contains("HIS-ORACLE-01", verdict.PrincipalContradiction);
            Assert.Contains("非终端 PC 故障", verdict.PrincipalContradiction);
            Assert.True(verdict.Confidence >= 0.85);
            Assert.Contains("无需排查门诊终端", verdict.ActionAdvice);
        }
    }
}
