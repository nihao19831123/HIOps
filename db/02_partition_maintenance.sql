-- ==============================================================================
-- HIOps 自动化时序分区表维护存储过程 (PostgreSQL 17.5)
-- 作用：每日自动预建未来 3 天分区，并安全 DROP 清理超过 7 天的历史分区，防止磁盘膨胀
-- ==============================================================================

CREATE OR REPLACE FUNCTION maintain_telemetry_partitions() RETURNS void AS $$
DECLARE
    today_date DATE := CURRENT_DATE;
    partition_date DATE;
    partition_name TEXT;
    start_ts TEXT;
    end_ts TEXT;
BEGIN
    -- 1. 自动预建未来 3 天的每日分区 (确保任何时刻都有对应分区接收探针写入)
    FOR i IN 0..3 LOOP
        partition_date := today_date + i;
        partition_name := 'telemetry_terminal_probes_' || to_char(partition_date, 'YYYYMMDD');
        start_ts := to_char(partition_date, 'YYYY-MM-DD 00:00:00+08');
        end_ts := to_char(partition_date + 1, 'YYYY-MM-DD 00:00:00+08');

        IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = partition_name) THEN
            EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF telemetry_terminal_probes FOR VALUES FROM (%L) TO (%L);', 
                           partition_name, start_ts, end_ts);
            RAISE NOTICE 'Partition created: % (Range: % to %)', partition_name, start_ts, end_ts;
        END IF;
    END LOOP;

    -- 2. 自动清理 7 天前的历史废弃分区 (释放物理磁盘空间)
    FOR partition_name IN 
        SELECT tablename FROM pg_tables 
        WHERE tablename LIKE 'telemetry_terminal_probes_%' 
          AND to_date(substr(tablename, 27), 'YYYYMMDD') < today_date - 7
    LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I;', partition_name);
        RAISE NOTICE 'Expired partition dropped: %', partition_name;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 立即执行一次以创建当前和未来分区
SELECT maintain_telemetry_partitions();
