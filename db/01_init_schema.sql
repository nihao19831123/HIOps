-- ==============================================================================
-- HIOps 医院智能信息运维平台 — 数据库核心初始化脚本 (PostgreSQL 17.5)
-- 包含：CMDB资产拓扑、时序微探针每日分区表、因果时光机大对象JSONB、事故多维聚类与主要矛盾
-- ==============================================================================

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. CMDB 与物理拓扑域
-- ------------------------------------------------------------------------------

-- 终端网段与接入交换机字典表
CREATE TABLE IF NOT EXISTS cmdb_network_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_prefix VARCHAR(32) NOT NULL UNIQUE,  -- 如 '192.168.20.'
    segment_name VARCHAR(64) NOT NULL,           -- 如 '门诊西区收费与急诊网段'
    gateway_ip VARCHAR(32) NOT NULL,             -- 网关 IP: 192.168.20.1
    switch_ip VARCHAR(32) NOT NULL,              -- 核心接入交换机 IP: 192.168.20.254
    switch_port VARCHAR(32),                     -- 交换机上行端口
    physical_location VARCHAR(128),              -- 物理位置: 门诊楼2层弱电井
    is_monitored BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 资产台账与终端状态表
CREATE TABLE IF NOT EXISTS cmdb_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_code VARCHAR(64) NOT NULL UNIQUE,     -- 资产指纹 (MAC + 主机名Hash)
    host_name VARCHAR(128) NOT NULL,            -- 计算机名 (如 MZ-W-021)
    ip_address VARCHAR(32) NOT NULL,
    mac_address VARCHAR(32) NOT NULL,
    segment_id UUID REFERENCES cmdb_network_segments(id),
    department_name VARCHAR(64) NOT NULL,       -- 物理科室 (如 门诊收费处)
    os_name VARCHAR(64) NOT NULL,               -- Windows 7 SP1 x86, Windows 10 x64
    client_version VARCHAR(32),                 -- Sensor 版本号 (如 2.0.1)
    zabbix_host_id BIGINT,                      -- 关联的 Zabbix HostID
    source VARCHAR(32) DEFAULT 'SENSOR-AUTO',   -- ZABBIX-SYNC, SENSOR-AUTO, MANUAL
    is_online BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_assets_ip_mac ON cmdb_assets(ip_address, mac_address);
CREATE INDEX IF NOT EXISTS idx_assets_segment ON cmdb_assets(segment_id);
CREATE INDEX IF NOT EXISTS idx_assets_online ON cmdb_assets(is_online);

-- ------------------------------------------------------------------------------
-- 2. 异常指纹、前序因果时光机与确定性复现包域
-- ------------------------------------------------------------------------------

-- 异常堆栈指纹库 (去重与解决方案知识库)
CREATE TABLE IF NOT EXISTS crash_fingerprints (
    fingerprint_hash VARCHAR(64) PRIMARY KEY,   -- SHA1(Process + Module + Code + Stack)
    process_name VARCHAR(128) NOT NULL,         -- 如 HIS.exe
    faulting_module VARCHAR(128) NOT NULL,      -- 如 oraoci.dll
    exception_code VARCHAR(32) NOT NULL,        -- 如 0xc0000005
    first_seen_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    occurrence_count INT DEFAULT 1,
    known_solution TEXT,                        -- 知识库预案
    suggested_action VARCHAR(64)                -- AUTO_RESTART_SPOOLER, RE_REGISTER_COM
);

-- 确定性复现快照主表 (因果时光机 + 现场截屏 + 微环境时序)
CREATE TABLE IF NOT EXISTS forensics_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fingerprint_hash VARCHAR(64) REFERENCES crash_fingerprints(fingerprint_hash),
    asset_id UUID NOT NULL REFERENCES cmdb_assets(id),
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    trigger_type VARCHAR(32) NOT NULL,          -- UI_HANG, CRASH_WER, MANUAL_HOTKEY
    hang_duration_ms INT DEFAULT 0,             -- 卡死毫秒数
    active_window_title VARCHAR(256),           -- 故障前台窗口标题
    ocr_error_text TEXT,                        -- OCR 提取的弹窗错误文本 (如 ORA-00054)
    action_trail JSONB NOT NULL,                -- 前序 60s 操作序列 (点击/扫码/切窗)
    dependency_timeline JSONB NOT NULL,         -- 接口依赖时序 (耗时/状态码)
    net_rtt_timeline JSONB NOT NULL,            -- 前序 3 分钟 TCP RTT 曲线
    stack_trace TEXT,                           -- 线程调用栈
    screenshot_thumb BYTEA,                     -- 经过脱敏处理的高压缩缩略图
    screenshot_path VARCHAR(256),               -- 高清脱敏截图文件系统存储路径
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_forensics_asset_time ON forensics_snapshots(asset_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_forensics_fingerprint ON forensics_snapshots(fingerprint_hash);
CREATE INDEX IF NOT EXISTS idx_forensics_action_trail ON forensics_snapshots USING gin(action_trail);

-- ------------------------------------------------------------------------------
-- 3. 事故单、滑动窗口聚类与主要矛盾域 (Incidents & RCA)
-- ------------------------------------------------------------------------------

-- 事故指挥主单 (主要矛盾、多维聚类收敛)
CREATE TABLE IF NOT EXISTS incident_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_no VARCHAR(32) NOT NULL UNIQUE,    -- 编号: INC-YYYYMMDD-XXXX
    title VARCHAR(256) NOT NULL,                -- 标题: [P2-局部网络事故] 门诊西区接入交换机丢包
    severity_level VARCHAR(8) NOT NULL,         -- P1, P2, P3, P4
    status VARCHAR(16) NOT NULL DEFAULT 'OPEN', -- OPEN, INVESTIGATING, MITIGATED, RESOLVED
    cluster_dimension VARCHAR(32) NOT NULL,     -- SEGMENT, SWITCH, APP_VERSION, ISOLATED
    dimension_key VARCHAR(64) NOT NULL,         -- 如 '192.168.20.'
    affected_count INT DEFAULT 1,               -- 受波及终端数
    principal_contradiction TEXT,               -- 主要矛盾判定: "核心数据库行锁争用，非终端故障"
    root_cause_asset_id UUID REFERENCES cmdb_assets(id), -- 根因发起设备 (如 HIS-DB-01)
    root_confidence FLOAT DEFAULT 0.0,          -- 根因置信度 (0.00 ~ 1.00)
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    auto_suppressed_count INT DEFAULT 0,        -- 本次事故自动抑制的次生告警数
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_incidents_status_level ON incident_incidents(status, severity_level);
CREATE INDEX IF NOT EXISTS idx_incidents_started ON incident_incidents(started_at DESC);

-- 原生事件流表 (带主从合并与抑制标记)
CREATE TABLE IF NOT EXISTS incident_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID REFERENCES incident_incidents(id) ON DELETE SET NULL,
    asset_id UUID NOT NULL REFERENCES cmdb_assets(id),
    snapshot_id UUID REFERENCES forensics_snapshots(id),
    event_type VARCHAR(64) NOT NULL,            -- UI_HANG, DB_TIMEOUT, PORT_DOWN, PLUNGE
    severity VARCHAR(16) NOT NULL,              -- CRITICAL, WARNING, INFO
    is_suppressed BOOLEAN DEFAULT FALSE,        -- 是否被拓扑或滑动窗口抑制
    suppress_reason VARCHAR(64),                -- TOPOLOGY_PARENT_DOWN, SLIDING_WINDOW_ROLLUP
    raw_payload JSONB,                          -- 原始事件 JSON
    triggered_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_events_incident_id ON incident_events(incident_id);
CREATE INDEX IF NOT EXISTS idx_events_asset_time ON incident_events(asset_id, triggered_at DESC);

-- 拓扑依赖告警抑制规则表
CREATE TABLE IF NOT EXISTS incident_inhibition_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_name VARCHAR(64) NOT NULL,
    parent_type VARCHAR(32) NOT NULL,           -- 如 SWITCH_DOWN, DB_HANG
    target_event_type VARCHAR(32) NOT NULL,     -- 如 TERMINAL_TIMEOUT, PC_PING_LOSS
    scope_expression VARCHAR(128) NOT NULL,     -- 作用拓扑范围: 'SAME_SEGMENT', 'SAME_SWITCH'
    duration_seconds INT DEFAULT 300,           -- 抑制窗口秒数
    is_enabled BOOLEAN DEFAULT TRUE
);

-- ------------------------------------------------------------------------------
-- 4. 时序微探针 (原生按天范围分区大表)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS telemetry_terminal_probes (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    asset_id UUID NOT NULL,
    target_service VARCHAR(32) NOT NULL,        -- ORACLE_1521, HIS_GATEWAY_8080
    rtt_ms FLOAT NOT NULL,                      -- TCP SYN 握手延时 (毫秒)
    packet_loss_rate FLOAT DEFAULT 0.0,         -- 丢包率 (0.0 ~ 1.0)
    reported_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id, reported_at)
) PARTITION BY RANGE (reported_at);

-- 本地分区索引
CREATE INDEX IF NOT EXISTS idx_probes_asset_time ON telemetry_terminal_probes (asset_id, reported_at DESC);

-- ------------------------------------------------------------------------------
-- 5. 仿真假人拨测与业务黄金指标域
-- ------------------------------------------------------------------------------

-- 假人仿真巡检任务
CREATE TABLE IF NOT EXISTS synthetic_probe_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_name VARCHAR(64) NOT NULL,              -- 早高峰开方仿真假人
    schedule_cron VARCHAR(32) NOT NULL,         -- '*/1 7-8 * * 1-5'
    target_system VARCHAR(32) NOT NULL,         -- HIS_CLINIC, INSUR_GATEWAY
    probe_steps JSONB NOT NULL,                 -- [CardRead, Prescribe, Trial, Rollback]
    timeout_threshold_ms INT DEFAULT 3000,      -- 超时告警阈值
    is_active BOOLEAN DEFAULT TRUE,
    last_run_at TIMESTAMP WITH TIME ZONE,
    last_status VARCHAR(16)                     -- SUCCESS, DEGRADED, FAILED
);

-- 业务黄金指标吞吐脉搏表 (分钟级聚合)
CREATE TABLE IF NOT EXISTS business_golden_metrics (
    metric_time TIMESTAMP WITH TIME ZONE PRIMARY KEY,
    registration_count INT DEFAULT 0,           -- 过去1分钟全院挂号笔数
    prescription_count INT DEFAULT 0,           -- 过去1分钟全院处方开立笔数
    insurance_settle_count INT DEFAULT 0,       -- 过去1分钟医保结算笔数
    insurance_success_rate FLOAT DEFAULT 1.0,   -- 医保结算成功率
    baseline_expected_rate FLOAT,               -- 动态基线期望值
    is_plunge_anomaly BOOLEAN DEFAULT FALSE     -- 是否触发断崖式下跌判定
);

CREATE INDEX IF NOT EXISTS idx_golden_time ON business_golden_metrics(metric_time DESC);

-- ------------------------------------------------------------------------------
-- 6. 本地自愈与工单闭环域
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ops_self_healing_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES cmdb_assets(id),
    action_type VARCHAR(64) NOT NULL,           -- RESTART_SPOOLER, FLUSH_DNS, CLEAR_TEMP
    trigger_source VARCHAR(32) NOT NULL,        -- USER_HOTKEY, AUTO_POLICY
    is_success BOOLEAN NOT NULL,
    duration_ms INT NOT NULL,
    output_message TEXT,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_self_healing_asset ON ops_self_healing_logs(asset_id, executed_at DESC);
