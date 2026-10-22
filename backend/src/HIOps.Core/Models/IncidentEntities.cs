using System;
using System.Collections.Generic;

namespace HIOps.Core.Models
{
    public class Incident
    {
        public Guid Id { get; set; }
        public string IncidentNo { get; set; }
        public string Title { get; set; }
        public string SeverityLevel { get; set; } // P1, P2, P3, P4
        public string Status { get; set; } // OPEN, INVESTIGATING, MITIGATED, RESOLVED
        public string ClusterDimension { get; set; } // SEGMENT, SWITCH, APP_VERSION, ISOLATED
        public string DimensionKey { get; set; }
        public int AffectedCount { get; set; }
        public string PrincipalContradiction { get; set; }
        public Guid? RootCauseAssetId { get; set; }
        public string RootCauseAssetName { get; set; }
        public double RootConfidence { get; set; }
        public DateTime StartedAt { get; set; }
        public DateTime? ResolvedAt { get; set; }
        public int AutoSuppressedCount { get; set; }
        public List<IncidentEvent> ChildEvents { get; set; }

        public Incident()
        {
            Id = Guid.NewGuid();
            Status = "OPEN";
            AffectedCount = 1;
            StartedAt = DateTime.UtcNow;
            ChildEvents = new List<IncidentEvent>();
        }
    }

    public class IncidentEvent
    {
        public Guid Id { get; set; }
        public Guid? IncidentId { get; set; }
        public Guid AssetId { get; set; }
        public string SourceAssetName { get; set; }
        public string SegmentPrefix { get; set; }
        public string SwitchId { get; set; }
        public string AppVersion { get; set; }
        public string EventType { get; set; } // UI_HANG, DB_TIMEOUT, PORT_DOWN, PLUNGE
        public string Severity { get; set; } // CRITICAL, WARNING, INFO
        public double TopologyDepth { get; set; } // 1.0 (DB) -> 0.1 (Terminal)
        public bool IsSuppressed { get; set; }
        public string SuppressReason { get; set; }
        public string FingerprintHash { get; set; }
        public DateTime TriggeredAt { get; set; }

        public IncidentEvent()
        {
            Id = Guid.NewGuid();
            TriggeredAt = DateTime.UtcNow;
        }
    }

    public class RcaVerdict
    {
        public string PrincipalContradiction { get; set; }
        public Guid? RootAssetId { get; set; }
        public string RootAssetName { get; set; }
        public double Confidence { get; set; }
        public string ActionAdvice { get; set; }
    }
}
