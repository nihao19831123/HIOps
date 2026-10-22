using System;
using System.Collections.Generic;
using System.Linq;

namespace HIOps.Core.Engines
{
    /// <summary>
    /// 核心业务量“断崖下跌”突变检测器 (Plunge Anomaly Detector)
    /// 针对“指标全绿、业务全瘫”场景：若早高峰挂号/处方量连续 2 分钟跌幅 > 80%，秒级触发重大事故
    /// </summary>
    public class PlungeAnomalyDetector
    {
        public class MetricPoint
        {
            public DateTime Timestamp { get; set; }
            public int Volume { get; set; } // 过去 1 分钟开立处方数或挂号数
            public double BaselineExpected { get; set; } // 动态基线期望值
        }

        private readonly double _dropThresholdPercentage;

        public PlungeAnomalyDetector(double dropThresholdPercentage = 0.80)
        {
            _dropThresholdPercentage = dropThresholdPercentage;
        }

        public bool CheckPlungeAnomaly(List<MetricPoint> recentPoints, out string alertReason)
        {
            alertReason = null;
            if (recentPoints == null || recentPoints.Count < 2) return false;

            var lastTwo = recentPoints.OrderByDescending(p => p.Timestamp).Take(2).ToList();

            bool isConsecutiveDrop = true;
            double avgDrop = 0;

            foreach (var pt in lastTwo)
            {
                if (pt.BaselineExpected <= 10)
                {
                    isConsecutiveDrop = false;
                    break;
                }

                double dropRate = (pt.BaselineExpected - pt.Volume) / pt.BaselineExpected;
                if (dropRate < _dropThresholdPercentage)
                {
                    isConsecutiveDrop = false;
                    break;
                }
                avgDrop += dropRate;
            }

            if (isConsecutiveDrop)
            {
                avgDrop /= 2.0;
                alertReason = string.Format("检测到核心业务吞吐量连续 2 分钟断崖式暴跌 (平均跌幅 {0:P1}，当前实际吞吐 {1}/分，基线预期 {2:F0}/分)",
                    avgDrop, lastTwo[0].Volume, lastTwo[0].BaselineExpected);
                return true;
            }

            return false;
        }
    }
}
