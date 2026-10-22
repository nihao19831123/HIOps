using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Sockets;
using System.Threading.Tasks;
using HIOps.EndpointSensor.Models;

namespace HIOps.EndpointSensor.Core
{
    /// <summary>
    /// 端侧合成网络微探针
    /// 每 5 秒对核心数据库 (1521) 和业务网关 (8080) 执行轻量 TCP SYN 探测
    /// </summary>
    public class SyntheticNetProbe
    {
        public class TargetEndpoint
        {
            public string Name { get; set; }
            public string Host { get; set; }
            public int Port { get; set; }
        }

        private readonly List<TargetEndpoint> _targets = new List<TargetEndpoint>
        {
            new TargetEndpoint { Name = "ZABBIX_HTTP_80", Host = "192.168.114.29", Port = 80 },
            new TargetEndpoint { Name = "ZABBIX_SRV_10051", Host = "192.168.114.29", Port = 10051 },
            new TargetEndpoint { Name = "HIOPS_API_5080", Host = "192.168.114.30", Port = 5080 }
        };

        public async Task<List<NetProbeResult>> ProbeAllAsync(int timeoutMs = 2000)
        {
            var results = new List<NetProbeResult>();
            foreach (var target in _targets)
            {
                var result = await ProbeSingleAsync(target, timeoutMs);
                results.Add(result);
            }
            return results;
        }

        private async Task<NetProbeResult> ProbeSingleAsync(TargetEndpoint target, int timeoutMs)
        {
            var sw = Stopwatch.StartNew();
            using (var client = new TcpClient())
            {
                try
                {
                    var connectTask = client.ConnectAsync(target.Host, target.Port);
                    var delayTask = Task.Delay(timeoutMs);

                    var completed = await Task.WhenAny(connectTask, delayTask);
                    sw.Stop();

                    if (completed == connectTask && client.Connected)
                    {
                        return new NetProbeResult
                        {
                            TargetService = target.Name,
                            RttMs = Math.Round(sw.Elapsed.TotalMilliseconds, 2),
                            LossRate = 0.0
                        };
                    }
                    else
                    {
                        return new NetProbeResult
                        {
                            TargetService = target.Name,
                            RttMs = timeoutMs,
                            LossRate = 1.0 // 100% 丢包/超时
                        };
                    }
                }
                catch
                {
                    return new NetProbeResult
                    {
                        TargetService = target.Name,
                        RttMs = timeoutMs,
                        LossRate = 1.0
                    };
                }
            }
        }
    }
}
