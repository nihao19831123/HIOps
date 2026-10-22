using System;
using System.Collections.Generic;
using System.Linq;
using HIOps.Core.Models;

namespace HIOps.Core.Engines
{
    /// <summary>
    /// 主要矛盾因果分析裁决器 (RCA Arbiter)
    /// 数学模型: Score = 0.4*TimePrecedence + 0.35*TopologicalDepth + 0.25*BlastRadiusExplain
    /// 在数百个报警事件中识别唯一主因，将从属表象自动折叠
    /// </summary>
    public class PrincipalRcaArbiter
    {
        public RcaVerdict Arbitrate(List<IncidentEvent> clusterEvents)
        {
            if (clusterEvents == null || clusterEvents.Count == 0)
            {
                return new RcaVerdict
                {
                    PrincipalContradiction = "无可用事件进行因果分析",
                    Confidence = 0.0,
                    ActionAdvice = "暂无建议"
                };
            }

            DateTime minTime = clusterEvents.Min(e => e.TriggeredAt);
            DateTime maxTime = clusterEvents.Max(e => e.TriggeredAt);
            double totalSpanSeconds = Math.Max(1.0, (maxTime - minTime).TotalSeconds);

            IncidentEvent bestCandidate = null;
            double highestScore = -1.0;

            foreach (var ev in clusterEvents)
            {
                // 1. 时间先发性得分 (越早发生得分越高，1.0 满分)
                double timeDelay = (ev.TriggeredAt - minTime).TotalSeconds;
                double timeScore = Math.Max(0.0, 1.0 - (timeDelay / totalSpanSeconds));

                // 2. 拓扑深度得分 (核心数据库 1.0, 核心网络 0.85, 中间件 0.7, 终端 0.1)
                double depthScore = ev.TopologyDepth > 0 ? ev.TopologyDepth : 0.1;

                // 3. 解释度得分 (若属于全局性阻断事件，解释度满分)
                double explainScore = (ev.EventType.Contains("LOCK") || ev.EventType.Contains("DOWN") || ev.EventType.Contains("PLUNGE")) ? 1.0 : 0.3;

                // 综合评分
                double totalScore = (0.40 * timeScore) + (0.35 * depthScore) + (0.25 * explainScore);

                if (totalScore > highestScore)
                {
                    highestScore = totalScore;
                    bestCandidate = ev;
                }
            }

            // 生成结构化裁决结论
            if (bestCandidate != null)
            {
                if (bestCandidate.TopologyDepth >= 0.7)
                {
                    return new RcaVerdict
                    {
                        PrincipalContradiction = string.Format("[{0}] 发生 {1}，引发全链路阻塞 (非终端 PC 故障)", bestCandidate.SourceAssetName, bestCandidate.EventType),
                        RootAssetId = bestCandidate.AssetId,
                        RootAssetName = bestCandidate.SourceAssetName,
                        Confidence = Math.Round(Math.Min(0.98, highestScore), 2),
                        ActionAdvice = "处置核心服务/杀死数据库锁源会话，无需排查门诊终端"
                    };
                }
                else if (bestCandidate.EventType.Contains("PORT") || bestCandidate.EventType.Contains("LOSS"))
                {
                    return new RcaVerdict
                    {
                        PrincipalContradiction = string.Format("弱电接入层网络抖动/端口错包，引发终端批量丢包 ({0})", bestCandidate.SourceAssetName),
                        RootAssetId = bestCandidate.AssetId,
                        RootAssetName = bestCandidate.SourceAssetName,
                        Confidence = Math.Round(Math.Min(0.92, highestScore), 2),
                        ActionAdvice = "派单网络科排查对应楼层弱电井跳线与交换机端口"
                    };
                }
                else
                {
                    return new RcaVerdict
                    {
                        PrincipalContradiction = string.Format("特定终端客户端缺陷或组件损坏 ({0} 报 {1})", bestCandidate.SourceAssetName, bestCandidate.EventType),
                        RootAssetId = bestCandidate.AssetId,
                        RootAssetName = bestCandidate.SourceAssetName,
                        Confidence = Math.Round(Math.Min(0.85, highestScore), 2),
                        ActionAdvice = "推送桌面小助手一键自愈，或重新注册 COM 组件"
                    };
                }
            }

            return new RcaVerdict
            {
                PrincipalContradiction = "未检测到明显因果主矛盾",
                Confidence = 0.5,
                ActionAdvice = "人工介入排查"
            };
        }
    }
}
