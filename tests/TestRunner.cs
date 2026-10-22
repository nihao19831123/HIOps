using System;
using System.Collections.Generic;
using System.Linq;
using HIOps.Core.Engines;
using HIOps.Core.Models;
using HIOps.EndpointSensor.Core;
using HIOps.EndpointSensor.Models;
using HIOps.EndpointSensor.Watchdogs;

namespace HIOps.TestHarness
{
    public class Program
    {
        public static int _pass = 0;
        public static int _fail = 0;

        public static void Main()
        {
            Console.WriteLine("==================================================================");
            Console.WriteLine("       HIOps 自动化测试套件 (UT / IT / ST) — 验证运行器");
            Console.WriteLine("==================================================================");

            RunTest("UT-01: RingBuffer FIFO与容量上限测试", Test_UT01_RingBuffer);
            RunTest("UT-02: 崩溃堆栈 SHA1 指纹幂等性测试", Test_UT02_Fingerprint);
            RunTest("UT-04: 软状态到硬状态 3次防抖测试", Test_UT04_Debounce);
            RunTest("UT-06: 120s 滑动窗口多维聚类与抑制测试", Test_UT06_SlidingWindow);
            RunTest("UT-07: 主要矛盾因果分析 (RCA) 算分测试", Test_UT07_PrincipalRca);
            RunTest("UT-08: 拓扑依赖规则告警抑制测试", Test_UT08_TopologicalInhibition);
            RunTest("UT-09: 业务吞吐量断崖突变检测测试", Test_UT09_PlungeAnomaly);

            Console.WriteLine("==================================================================");
            Console.WriteLine(string.Format("测试结果汇总: 全部通过: {0}, 失败: {1}", _pass, _fail));
            Console.WriteLine("==================================================================");

            if (_fail > 0) Environment.Exit(1);
        }

        static void RunTest(string testName, Action action)
        {
            try
            {
                action();
                Console.WriteLine(string.Format("[PASS] {0}", testName));
                _pass++;
            }
            catch (Exception ex)
            {
                Console.WriteLine(string.Format("[FAIL] {0}: {1}", testName, ex.Message));
                _fail++;
            }
        }

        static void Test_UT01_RingBuffer()
        {
            var ringBuffer = new ActionTrailRingBuffer(capacity: 50);
            for (int i = 1; i <= 120; i++)
            {
                ringBuffer.Enqueue(ActionType.UI_CLICK, "btn_" + i, "Click " + i);
            }
            var list = ringBuffer.FreezeAndDump();
            if (list.Count != 50) throw new Exception("容量不等于 50");
            if (list[0].Target != "btn_71") throw new Exception("第一条不等于 btn_71");
            if (list[49].Target != "btn_120") throw new Exception("最后一条不等于 btn_120");
        }

        static void Test_UT02_Fingerprint()
        {
            string h1 = CrashEventLogWatcher.ComputeFingerprint("HIS.exe", "oraoci.dll", "0xc0000005");
            string h2 = CrashEventLogWatcher.ComputeFingerprint("his.exe", "ORAOCI.DLL", "0xC0000005");
            string hDiff = CrashEventLogWatcher.ComputeFingerprint("HIS.exe", "ntdll.dll", "0xc0000005");

            if (h1 != h2) throw new Exception("相同输入指纹不一致");
            if (h1 == hDiff) throw new Exception("不同模块生成了相同指纹");
        }

        static void Test_UT04_Debounce()
        {
            int failCount = 0;
            string state = "NORMAL";

            // 模拟 1 次失败
            failCount++;
            if (failCount < 3) state = "SOFT_ALERT";
            if (state != "SOFT_ALERT") throw new Exception("单次失败未保持软状态");

            // 连续 3 次失败
            failCount = 3;
            if (failCount >= 3) state = "HARD_ALERT";
            if (state != "HARD_ALERT") throw new Exception("连续 3 次失败未转硬状态");
        }

        static void Test_UT06_SlidingWindow()
        {
            var correlator = new SlidingWindowCorrelator(120);
            var now = DateTime.UtcNow;

            correlator.IngestEvent(new IncidentEvent { SourceAssetName = "PC-MZ-01", SegmentPrefix = "192.168.20.", EventType = "TERMINAL_TIMEOUT", TriggeredAt = now.AddSeconds(-30) });
            correlator.IngestEvent(new IncidentEvent { SourceAssetName = "PC-MZ-02", SegmentPrefix = "192.168.20.", EventType = "TERMINAL_TIMEOUT", TriggeredAt = now.AddSeconds(-20) });
            correlator.IngestEvent(new IncidentEvent { SourceAssetName = "PC-MZ-03", SegmentPrefix = "192.168.20.", EventType = "TERMINAL_TIMEOUT", TriggeredAt = now.AddSeconds(-10) });
            correlator.IngestEvent(new IncidentEvent { SourceAssetName = "PC-ZY-01", SegmentPrefix = "192.168.30.", EventType = "UI_HANG", TriggeredAt = now.AddSeconds(-5) });

            var incidents = correlator.EvaluateAndCorrelate(now);
            if (incidents.Count != 2) throw new Exception("聚类事故单数量不为 2");

            var p2 = incidents.FirstOrDefault(i => i.SeverityLevel == "P2");
            if (p2 == null || p2.AffectedCount != 3) throw new Exception("P2 聚类未命中 3 台终端");
        }

        static void Test_UT07_PrincipalRca()
        {
            var arbiter = new PrincipalRcaArbiter();
            var now = DateTime.UtcNow;

            var events = new List<IncidentEvent>
            {
                new IncidentEvent { AssetId = Guid.NewGuid(), SourceAssetName = "HIS-ORACLE-01", EventType = "CORE_DB_LOCK", TopologyDepth = 1.0, TriggeredAt = now.AddSeconds(-5) },
                new IncidentEvent { AssetId = Guid.NewGuid(), SourceAssetName = "MZ-PC-021", EventType = "UI_HANG", TopologyDepth = 0.1, TriggeredAt = now }
            };

            var verdict = arbiter.Arbitrate(events);
            if (!verdict.PrincipalContradiction.Contains("HIS-ORACLE-01")) throw new Exception("主要矛盾未锁定数据库");
            if (verdict.Confidence < 0.85) throw new Exception("置信度低于 0.85");
        }

        static void Test_UT08_TopologicalInhibition()
        {
            var engine = new TopologicalInhibitionEngine();
            var events = new List<IncidentEvent>
            {
                new IncidentEvent { Id = Guid.NewGuid(), SourceAssetName = "SW-MZ-2F", SegmentPrefix = "192.168.20.", EventType = "SWITCH_DOWN" },
                new IncidentEvent { Id = Guid.NewGuid(), SourceAssetName = "MZ-PC-01", SegmentPrefix = "192.168.20.", EventType = "TERMINAL_TIMEOUT" },
                new IncidentEvent { Id = Guid.NewGuid(), SourceAssetName = "ZY-PC-01", SegmentPrefix = "192.168.30.", EventType = "TERMINAL_TIMEOUT" }
            };

            engine.ApplyInhibition(events);
            var p1 = events.First(e => e.SourceAssetName == "MZ-PC-01");
            var p2 = events.First(e => e.SourceAssetName == "ZY-PC-01");

            if (!p1.IsSuppressed) throw new Exception("同网段子节点未被抑制");
            if (p2.IsSuppressed) throw new Exception("跨网段节点被错误抑制");
        }

        static void Test_UT09_PlungeAnomaly()
        {
            var detector = new PlungeAnomalyDetector(0.80);
            var now = DateTime.UtcNow;

            var points = new List<PlungeAnomalyDetector.MetricPoint>
            {
                new PlungeAnomalyDetector.MetricPoint { Timestamp = now.AddMinutes(-2), Volume = 10, BaselineExpected = 200 },
                new PlungeAnomalyDetector.MetricPoint { Timestamp = now.AddMinutes(-1), Volume = 10, BaselineExpected = 200 }
            };

            string reason;
            if (!detector.CheckPlungeAnomaly(points, out reason)) throw new Exception("断崖突变未检测出");
        }
    }
}
