using System;
using System.Collections.Generic;
using System.Linq;
using HIOps.Core.Models;

namespace HIOps.Core.Engines
{
    /// <summary>
    /// 拓扑依赖告警抑制引擎 (Alert Inhibition Engine)
    /// 铁律:『根节点已死，屏蔽所有子节点衍生告警』
    /// 核心交换机挂掉，自动静默下游 500 台 PC 的 Ping 离线告警，阻断告警风暴
    /// </summary>
    public class TopologicalInhibitionEngine
    {
        public class InhibitionRule
        {
            public string ParentEventType { get; set; }
            public string ChildEventType { get; set; }
            public Func<IncidentEvent, IncidentEvent, bool> ScopeMatch { get; set; }
        }

        private readonly List<InhibitionRule> _rules = new List<InhibitionRule>
        {
            // 规则 1: 交换机掉线抑制同网段所有终端超时
            new InhibitionRule
            {
                ParentEventType = "SWITCH_DOWN",
                ChildEventType = "TERMINAL_TIMEOUT",
                ScopeMatch = (parent, child) => parent.SegmentPrefix == child.SegmentPrefix
            },
            // 规则 2: 核心数据库锁表/故障抑制所有应用级卡死
            new InhibitionRule
            {
                ParentEventType = "CORE_DB_LOCK",
                ChildEventType = "UI_HANG",
                ScopeMatch = (parent, child) => true // 全局作用
            },
            // 规则 3: 医保前置网关超时抑制所有门诊试算报错
            new InhibitionRule
            {
                ParentEventType = "INSUR_GATEWAY_DOWN",
                ChildEventType = "INSUR_TIMEOUT",
                ScopeMatch = (parent, child) => true
            }
        };

        public void ApplyInhibition(List<IncidentEvent> events)
        {
            var parentEvents = events.Where(e => !e.IsSuppressed && IsParentEventType(e.EventType)).ToList();

            foreach (var parent in parentEvents)
            {
                foreach (var child in events)
                {
                    if (child.Id == parent.Id || child.IsSuppressed) continue;

                    // 检查是否命中抑制规则
                    var matchedRule = _rules.FirstOrDefault(r => 
                        r.ParentEventType == parent.EventType && 
                        r.ChildEventType == child.EventType && 
                        r.ScopeMatch(parent, child));

                    if (matchedRule != null)
                    {
                        child.IsSuppressed = true;
                        child.SuppressReason = string.Format("TOPOLOGY_INHIBITED_BY_{0}", parent.SourceAssetName);
                    }
                }
            }
        }

        private bool IsParentEventType(string eventType)
        {
            return eventType == "SWITCH_DOWN" || eventType == "CORE_DB_LOCK" || eventType == "INSUR_GATEWAY_DOWN";
        }
    }
}
