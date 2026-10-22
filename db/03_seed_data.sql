-- ==============================================================================
-- HIOps 医院网络拓扑种子数据与基线规则
-- ==============================================================================

-- 1. 插入医院 6 大终端物理网段
INSERT INTO cmdb_network_segments (segment_prefix, segment_name, gateway_ip, switch_ip, switch_port, physical_location)
VALUES 
('192.168.10.', '门诊诊区网段', '192.168.10.1', '192.168.10.254', 'GigabitEthernet0/1', '门诊楼1层弱电井'),
('192.168.20.', '门诊西区收费与急诊网段', '192.168.20.1', '192.168.20.254', 'GigabitEthernet0/2', '急诊楼1层弱电井'),
('192.168.30.', '住院部西区病房网段', '192.168.30.1', '192.168.30.254', 'GigabitEthernet0/3', '住院大楼4层弱电井'),
('192.168.31.', '住院部东区病房网段', '192.168.31.1', '192.168.31.254', 'GigabitEthernet0/4', '住院大楼8层弱电井'),
('192.168.40.', '医技检查与影像PACS网段', '192.168.40.1', '192.168.40.254', 'GigabitEthernet0/5', '医技综合楼2层弱电井'),
('192.168.50.', '机关与行政办公网段', '192.168.50.1', '192.168.50.254', 'GigabitEthernet0/6', '行政楼3层弱电井')
ON CONFLICT (segment_prefix) DO NOTHING;

-- 2. 预置已知异常指纹与解决方案库
INSERT INTO crash_fingerprints (fingerprint_hash, process_name, faulting_module, exception_code, known_solution, suggested_action)
VALUES
('FINGERPRINT_ORA_00054', 'HIS.exe', 'oraoci.dll', '0x80004005', '数据库行锁争用引发超时，通常由并发未防抖造成。杀死锁源会话。', 'AUTO_KILL_LOCK_SESSION'),
('FINGERPRINT_CRASH_ACCESS_VIOLATION', 'EMR.exe', 'ntdll.dll', '0xc0000005', '客户端动态库内存非法访问，常由于打印插件旧版本冲突导致。重新注册组件。', 'RE_REGISTER_COM'),
('FINGERPRINT_SPOOLER_DEADLOCK', 'spoolsv.exe', 'win32spl.dll', '0x000006ba', 'Windows 打印后台队列作业死锁。清空 PRINTERS 队列并重启 Spooler 服务。', 'AUTO_RESTART_SPOOLER')
ON CONFLICT (fingerprint_hash) DO NOTHING;

-- 3. 预置拓扑依赖抑制规则
INSERT INTO incident_inhibition_rules (rule_name, parent_type, target_event_type, scope_expression, duration_seconds)
VALUES
('核心交换机断网抑制子网终端', 'SWITCH_DOWN', 'TERMINAL_TIMEOUT', 'SAME_SEGMENT', 600),
('核心数据库挂死抑制应用超时', 'DB_HANG', 'UI_HANG', 'ALL_SEGMENTS', 300),
('医保前置机故障抑制试算报错', 'INSUR_GATEWAY_DOWN', 'INSUR_TIMEOUT', 'ALL_SEGMENTS', 600)
ON CONFLICT DO NOTHING;
