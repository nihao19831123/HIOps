import json, uuid, datetime, subprocess

def save_to_db(host, ip, trigger, win_title, ocr_error, stack_trace, action_trail, net_probes, fingerprint):
    inc_id = str(uuid.uuid4())
    evt_id = str(uuid.uuid4())
    rel_id = str(uuid.uuid4())
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    title = f"终端一键报障: {host} [{win_title[:30]}]"
    root_cause = f"窗口: {win_title[:100]}"
    if ocr_error:
        root_cause += f" | 报错: {ocr_error[:100]}"
    summary = f"终端 {host}({ip}) 发起一键报障; 触发: {trigger}; 窗口: {win_title[:50]}; 时序步骤: {len(action_trail)}条"

    desc = json.dumps({
        "action_trail": action_trail,
        "net_probes": net_probes,
        "ocr_error": ocr_error,
        "stack_trace": stack_trace
    }, ensure_ascii=False).replace("'", "''")

    safe_host = host.replace("'", "''")
    safe_title = title.replace("'", "''")
    safe_root_cause = root_cause.replace("'", "''")
    safe_summary = summary.replace("'", "''")
    safe_trigger = trigger.replace("'", "''")
    safe_fingerprint = fingerprint.replace("'", "''")

    sql = f"""
DO $$
DECLARE
    v_asset_id uuid;
BEGIN
    SELECT "Id" INTO v_asset_id FROM "Assets" WHERE lower("Hostname") = lower('{safe_host}') OR lower("Name") = lower('{safe_host}') LIMIT 1;
    IF v_asset_id IS NULL AND '{ip}' <> '' THEN
        SELECT "AssetId" INTO v_asset_id FROM "AssetIdentities" WHERE "IdentityType" = 'IP' AND "IdentityValue" = '{ip}' LIMIT 1;
    END IF;
    
    INSERT INTO "Incidents" ("Id", "Title", "Status", "Severity", "StartedAt", "RootAssetId", "RootCause", "Confidence", "BusinessImpact", "Summary")
    VALUES ('{inc_id}', '{safe_title}', 1, 2, '{now}', v_asset_id, '{safe_root_cause}', 0.95, '门诊临床终端异常 (一键报障)', '{safe_summary}');
    
    INSERT INTO "NormalizedEvents" ("Id", "EventId", "Timestamp", "Source", "AssetId", "EventType", "Severity", "Status", "Title", "Description", "Fingerprint")
    VALUES ('{evt_id}', 'EVT-{inc_id[:8]}', '{now}', 'SENSOR', v_asset_id, '{safe_trigger}', 'Warning', 'Open', '桌面故障快照: {safe_host}', '{desc[:4000]}', '{safe_fingerprint}');
    
    INSERT INTO "IncidentEvents" ("Id", "IncidentId", "EventId", "Relation")
    VALUES ('{rel_id}', '{inc_id}', '{evt_id}', 'Trigger');
END $$;
"""

    res = subprocess.run(["su", "-", "postgres", "-c", "psql -d hiops"], input=sql.encode('utf-8'), capture_output=True)
    print("Return code:", res.returncode)
    print("OUT:", res.stdout.decode('utf-8', errors='ignore'))
    print("ERR:", res.stderr.decode('utf-8', errors='ignore'))
    return inc_id, evt_id

inc_id, evt_id = save_to_db("PC-39-11", "192.168.39.11", "MANUAL_HOTKEY", "门诊收费系统", "ORA-03113 通信通道结束", "at System.Data...", [{"step": 1, "action": "click"}], [{"target": "192.168.2.17", "rtt": 2.5}], "fp123456")
print("Saved incident:", inc_id)

# verify in DB
check = subprocess.run(["su", "-", "postgres", "-c", f"psql -d hiops -c \"SELECT \\\"Id\\\", \\\"Title\\\", \\\"Status\\\", \\\"StartedAt\\\" FROM \\\"Incidents\\\" WHERE \\\"Id\\\" = '{inc_id}';\""], capture_output=True)
print("DB Verify:\n", check.stdout.decode('utf-8', errors='ignore'))

# clean up test row
subprocess.run(["su", "-", "postgres", "-c", f"psql -d hiops -c \"DELETE FROM \\\"IncidentEvents\\\" WHERE \\\"IncidentId\\\" = '{inc_id}'; DELETE FROM \\\"NormalizedEvents\\\" WHERE \\\"Id\\\" = '{evt_id}'; DELETE FROM \\\"Incidents\\\" WHERE \\\"Id\\\" = '{inc_id}';\""], capture_output=True)
print("Cleaned up.")
