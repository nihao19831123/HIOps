using System;
using System.Collections.Generic;
using System.Threading;
using HIOps.EndpointSensor.Models;

namespace HIOps.EndpointSensor.Core
{
    /// <summary>
    /// 因果时光机环形无锁/细粒度读写锁内存缓冲区
    /// 确保平时零磁盘 I/O，仅在内存滚动覆盖最近 50 条操作与时序流水
    /// </summary>
    public class ActionTrailRingBuffer
    {
        private readonly ActionEntry[] _buffer;
        private readonly int _capacity;
        private int _head = 0;
        private readonly ReaderWriterLockSlim _lock = new ReaderWriterLockSlim();

        public ActionTrailRingBuffer(int capacity = 50)
        {
            _capacity = capacity;
            _buffer = new ActionEntry[capacity];
        }

        public void Enqueue(ActionType type, string target, string detail)
        {
            var entry = new ActionEntry
            {
                Timestamp = DateTime.UtcNow,
                Type = type,
                Target = target,
                Detail = detail
            };

            _lock.EnterWriteLock();
            try
            {
                _buffer[_head] = entry;
                _head = (_head + 1) % _capacity;
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }

        public List<ActionEntry> FreezeAndDump()
        {
            _lock.EnterReadLock();
            try
            {
                var list = new List<ActionEntry>(_capacity);
                for (int i = 0; i < _capacity; i++)
                {
                    int idx = (_head + i) % _capacity;
                    if (_buffer[idx] != null)
                    {
                        list.Add(_buffer[idx]);
                    }
                }
                return list;
            }
            finally
            {
                _lock.ExitReadLock();
            }
        }
    }
}
