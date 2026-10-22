using System;
using Xunit;
using HIOps.EndpointSensor.Core;
using HIOps.EndpointSensor.Models;

namespace HIOps.UnitTests
{
    public class RingBufferTests
    {
        [Fact]
        public void RingBuffer_ShouldMaintainFIFO_WhenCapacityExceeded()
        {
            // Arrange (UT-01)
            var ringBuffer = new ActionTrailRingBuffer(capacity: 50);

            // Act: 写入 120 条数据
            for (int i = 1; i <= 120; i++)
            {
                ringBuffer.Enqueue(ActionType.UI_CLICK, $"btn_{i}", $"Click item {i}");
            }

            var snapshot = ringBuffer.FreezeAndDump();

            // Assert
            Assert.Equal(50, snapshot.Count);
            // 第一条应该是第 71 条输入，最后一条应该是第 120 条输入
            Assert.Equal("btn_71", snapshot[0].Target);
            Assert.Equal("btn_120", snapshot[49].Target);
        }
    }
}
