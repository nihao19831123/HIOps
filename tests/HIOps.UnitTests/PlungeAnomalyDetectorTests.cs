using System;
using System.Collections.Generic;
using Xunit;
using HIOps.Core.Engines;

namespace HIOps.UnitTests
{
    public class PlungeAnomalyDetectorTests
    {
        [Fact]
        public void Detector_ShouldFlagPlunge_WhenDropExceeds80Percent()
        {
            // Arrange (UT-09)
            var detector = new PlungeAnomalyDetector(dropThresholdPercentage: 0.80);
            var now = DateTime.UtcNow;

            // 模拟连续 2 分钟挂号量从基线 200 骤降至 10
            var points = new List<PlungeAnomalyDetector.MetricPoint>
            {
                new PlungeAnomalyDetector.MetricPoint
                {
                    Timestamp = now.AddMinutes(-2),
                    Volume = 12,
                    BaselineExpected = 200.0
                },
                new PlungeAnomalyDetector.MetricPoint
                {
                    Timestamp = now.AddMinutes(-1),
                    Volume = 8,
                    BaselineExpected = 200.0
                }
            };

            // Act
            bool isPlunge = detector.CheckPlungeAnomaly(points, out string reason);

            // Assert
            Assert.True(isPlunge);
            Assert.NotNull(reason);
            Assert.Contains("断崖式暴跌", reason);
        }

        [Fact]
        public void Detector_ShouldNotFlagPlunge_DuringLowVolumeOffHours()
        {
            // Arrange: 夜班闲时，业务量基数仅为 5，不应触发断崖误报
            var detector = new PlungeAnomalyDetector(dropThresholdPercentage: 0.80);
            var now = DateTime.UtcNow;

            var points = new List<PlungeAnomalyDetector.MetricPoint>
            {
                new PlungeAnomalyDetector.MetricPoint
                {
                    Timestamp = now.AddMinutes(-2),
                    Volume = 0,
                    BaselineExpected = 5.0
                },
                new PlungeAnomalyDetector.MetricPoint
                {
                    Timestamp = now.AddMinutes(-1),
                    Volume = 0,
                    BaselineExpected = 4.0
                }
            };

            // Act
            bool isPlunge = detector.CheckPlungeAnomaly(points, out string reason);

            // Assert
            Assert.False(isPlunge);
            Assert.Null(reason);
        }
    }
}
