using System;
using Xunit;
using HIOps.EndpointSensor.Watchdogs;

namespace HIOps.UnitTests
{
    public class FingerprintTests
    {
        [Fact]
        public void Generate_ShouldReturnIdenticalHash_ForSameException()
        {
            // Arrange & Act (UT-02)
            string hash1 = CrashEventLogWatcher.ComputeFingerprint("HIS.exe", "oraoci.dll", "0xc0000005");
            string hash2 = CrashEventLogWatcher.ComputeFingerprint("his.exe", "ORAOCI.DLL", "0xC0000005");
            string hashDiff = CrashEventLogWatcher.ComputeFingerprint("HIS.exe", "ntdll.dll", "0xc0000005");

            // Assert
            Assert.NotNull(hash1);
            Assert.Equal(hash1, hash2); // 忽略大小写保持幂等
            Assert.NotEqual(hash1, hashDiff); // 不同模块生成不同指纹
        }

        [Fact]
        public void ParseCrashDescription_ShouldExtractFieldsCorrectly()
        {
            string sampleDesc = @"
Faulting application name: HIS.exe, version: 5.2.1.0, time stamp: 0x61a8b29c
Faulting module name: oraoci.dll, version: 11.2.0.4, time stamp: 0x51d5d342
Exception code: 0xc0000005
Fault offset: 0x00014b20";

            var info = CrashEventLogWatcher.ParseCrashDescription(sampleDesc);

            Assert.NotNull(info);
            Assert.Equal("HIS.exe,", info.ProcessName + ",");
            Assert.Equal("oraoci.dll,", info.FaultingModule + ",");
            Assert.Equal("0xc0000005", info.ExceptionCode);
        }
    }
}
