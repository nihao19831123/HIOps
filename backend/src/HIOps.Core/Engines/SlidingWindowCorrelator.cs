using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using HIOps.Core.Models;

namespace HIOps.Core.Engines
{
    /// <summary>
    /// 120 秒多维滑动窗口聚类引擎 (借鉴 Keep / Alerta 模式)
    /// 按网段、接入交换机、软件版本收敛海量散碎告警，评定 P1-P4 影响面级别
    /// </summary>
    public class SlidingWindowCorrelator
    {
        private readonly List<IncidentEvent> _windowEvents = new List<IncidentEvent>();
        private readonly TimeSpan _windowDuration;
        private readonly object _lock = new object();

        public SlidingWindowCorrelator(int windowSeconds = 120)
        {
            _windowDuration = TimeSpan.FromSeconds(windowSeconds);
        }

        public void IngestEvent(IncidentEvent ev)
        {
            lock (_lock)
            {
                _windowEvents.Add(ev);
                PruneExpiredEvents(ev.TriggeredAt);
            }
        }

        public List<Incident> EvaluateAndCorrelate(DateTime currentTime)
        {
            lock (_lock)
            {
                PruneExpiredEvents(currentTime);
                var incidents = new List<Incident>();

                // 按网段 (Segment) 与接入交换机 (Switch) 分组
                var segmentGroups = _windowEvents
                    .Where(e => !string.IsNullOrEmpty(e.SegmentPrefix))
                    .GroupBy(e => e.SegmentPrefix)
                    .ToList();

                int activeClusters = 0;

                foreach (var group in segmentGroups)
                {
                    var eventsInGroup = group.ToList();
                    if (eventsInGroup.Count >= 3)
                    {
                        activeClusters++;
                        var inc = new Incident
                        {
                            IncidentNo = string.Format("INC-{0:yyyyMMddHHmm}-{1:D2}", currentTime, incidents.Count + 1),
                            Title = string.Format("[P2-局部区域网络/环境事故] 网段 {0} 发生异常聚合 ({1}台终端受波及)", group.Key, eventsInGroup.Count),
                            SeverityLevel = "P2",
                            ClusterDimension = "SEGMENT",
                            DimensionKey = group.Key,
                            AffectedCount = eventsInGroup.Count,
                            StartedAt = eventsInGroup.Min(e => e.TriggeredAt),
                            ChildEvents = eventsInGroup
                        };

                        // 标记次生告警被抑制
                        foreach (var e in eventsInGroup)
                        {
                            e.IsSuppressed = true;
                            e.SuppressReason = "SLIDING_WINDOW_ROLLUP";
                        }
                        inc.AutoSuppressedCount = eventsInGroup.Count - 1;

                        incidents.Add(inc);
                    }
                }

                // 规则：若多网段同时发生严重聚合，整体升级为 P1 全院级重大事故
                if (activeClusters >= 2 || _windowEvents.Any(e => e.EventType == "PLUNGE" || e.EventType == "CORE_DB_LOCK"))
                {
                    var p1Incident = new Incident
                    {
                        IncidentNo = string.Format("INC-{0:yyyyMMddHHmm}-CORE-P1", currentTime),
                        Title = string.Format("🚨 [P1-全院级重大事故] 核心业务系统大面积阻断 (波及 {0} 起异常)", _windowEvents.Count),
                        SeverityLevel = "P1",
                        ClusterDimension = "GLOBAL",
                        DimensionKey = "CORE_HOSPITAL_WIDE",
                        AffectedCount = _windowEvents.Count,
                        StartedAt = _windowEvents.Min(e => e.TriggeredAt),
                        ChildEvents = new List<IncidentEvent>(_windowEvents)
                    };
                    return new List<Incident> { p1Incident };
                }

                // 未成簇的孤立事件归为 P4 单机事件
                var isolatedEvents = _windowEvents.Where(e => !e.IsSuppressed).ToList();
                foreach (var iso in isolatedEvents)
                {
                    incidents.Add(new Incident
                    {
                        IncidentNo = string.Format("INC-{0:yyyyMMddHHmm}-{1}", currentTime, iso.Id.ToString().Substring(0, 4)),
                        Title = string.Format("[P4-单机特异故障] 终端 {0} 报 {1}", iso.SourceAssetName, iso.EventType),
                        SeverityLevel = "P4",
                        ClusterDimension = "ISOLATED",
                        DimensionKey = iso.SourceAssetName,
                        AffectedCount = 1,
                        StartedAt = iso.TriggeredAt,
                        ChildEvents = new List<IncidentEvent> { iso }
                    });
                }

                return incidents;
            }
        }

        private void PruneExpiredEvents(DateTime now)
        {
            _windowEvents.RemoveAll(e => now - e.TriggeredAt > _windowDuration);
        }
    }
}
