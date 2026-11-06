host = "XXK007"
win_title = "门诊医生站"
ocr_error = "连接超时"
trigger = "MANUAL_HOTKEY"
inc_id = "test-id-123"
now = "2026-10-29T12:00:00Z"
title = f"终端一键报障: {host} [{win_title[:30]}]"
root_cause = f"窗口: {win_title[:100]}"
summary = f"终端 {host} 发起一键报障"
evt_id = "test-evt-123"
rel_id = "test-rel-123"
fingerprint = "abc"
desc = "{}"

sql = f"""
DO $$
DECLARE
    v_asset_id uuid;
BEGIN
    SELECT "Id" INTO v_asset_id FROM "Assets" WHERE lower("Hostname") = lower('{host}') OR lower("Name") = lower('{host}') LIMIT 1;
    
    INSERT INTO "Incidents" ("Id", "Title", "Status", "Severity", "StartedAt", "RootAssetId", "RootCause", "Confidence", "BusinessImpact", "Summary")
    VALUES ('{inc_id}', '{title.replace("'", "''")}', 0, 2, '{now}', v_asset_id, '{root_cause.replace("'", "''")}', 0.95, '门诊临床终端异常 (一键报障)', '{summary.replace("'", "''")}');
    
    INSERT INTO "NormalizedEvents" ("Id", "EventId", "Timestamp", "Source", "AssetId", "EventType", "Severity", "Status", "Title", "Description", "Fingerprint")
    VALUES ('{evt_id}', 'EVT-{inc_id[:8]}', '{now}', 'SENSOR', v_asset_id, '{trigger}', 'Warning', 'Open', '桌面故障快照: {host}', '{desc[:4000]}', '{fingerprint}');
    
    INSERT INTO "IncidentEvents" ("Id", "IncidentId", "EventId", "Relation")
    VALUES ('{rel_id}', '{inc_id}', '{evt_id}', 'Trigger');
END $$;
"""
print("SQL is valid format:")
print(sql[:200])
