#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HIOps Oracle Read-Only Session & Lock Diagnostic Engine
Connects to hospital core Oracle database (192.168.0.48:1521/syyth)
using dedicated read-only account (hiops_ro_agent) to diagnose:
1. Target client session status, active waits, and blocking session (who blocked me?)
2. Blocker details (blocker SID, machine, OS user, program, and uncommitted SQL)
3. Hospital-wide lock tree (global blocking sessions holding up multiple clinic stations)
"""
import argparse
import datetime
import json
import os
import re
import socket
import sys
import time

ORACLE_HOST = os.environ.get("HIOPS_ORACLE_HOST", "192.168.0.48")
ORACLE_PORT = int(os.environ.get("HIOPS_ORACLE_PORT", "1521"))
ORACLE_SERVICE = os.environ.get("HIOPS_ORACLE_SERVICE", "syyth")
ORACLE_USER = os.environ.get("HIOPS_ORACLE_USER", "hiops_ro_agent")
ORACLE_PASSWORD = os.environ.get("HIOPS_ORACLE_PASSWORD", "qdsyxxk@60833")


def _get_connection(timeout=3):
    """Attempt connecting via oracledb (Thin mode) or fallback to cx_Oracle."""
    dsn = f"{ORACLE_HOST}:{ORACLE_PORT}/{ORACLE_SERVICE}"
    t0 = time.perf_counter()
    try:
        import oracledb
        conn = oracledb.connect(
            user=ORACLE_USER,
            password=ORACLE_PASSWORD,
            dsn=dsn,
            tcp_connect_timeout=timeout,
        )
        latency = round((time.perf_counter() - t0) * 1000, 1)
        return conn, "oracledb_thin", latency, None
    except ImportError:
        pass
    except Exception as e:
        latency = round((time.perf_counter() - t0) * 1000, 1)
        return None, "oracledb_error", latency, str(e)

    try:
        import cx_Oracle
        conn = cx_Oracle.connect(
            ORACLE_USER,
            ORACLE_PASSWORD,
            dsn,
        )
        latency = round((time.perf_counter() - t0) * 1000, 1)
        return conn, "cx_Oracle", latency, None
    except ImportError:
        return None, "missing_driver", 0, "Neither oracledb nor cx_Oracle is installed"
    except Exception as e:
        latency = round((time.perf_counter() - t0) * 1000, 1)
        return None, "cx_Oracle_error", latency, str(e)


def diagnose_client_oracle(ip="", host="", proc_name="", timeout=3.0):
    """
    Query Oracle v$session and lock views to diagnose clinical client blockage.
    Returns structured dict with diagnostic findings and a concise human-readable brief.
    """
    clean_ip = (ip or "").strip()
    clean_host = (host or "").strip()
    clean_proc = (proc_name or "").strip()

    conn, driver, latency_ms, err = _get_connection(timeout=timeout)
    if not conn:
        return {
            "enabled": True,
            "connected": False,
            "driver": driver,
            "latency_ms": latency_ms,
            "error": err,
            "is_blocked": False,
            "brief": f"Oracle只读诊断连接未就绪 ({err[:100]})",
            "global_blockers": [],
            "client_sessions": [],
        }

    diag = {
        "enabled": True,
        "connected": True,
        "driver": driver,
        "latency_ms": latency_ms,
        "target_ip": clean_ip,
        "target_host": clean_host,
        "is_blocked": False,
        "blocker": None,
        "client_sessions": [],
        "global_blockers": [],
        "brief": "",
    }

    try:
        cursor = conn.cursor()

        # 1. Query client sessions matching host / machine / ip
        host_pattern = f"%{clean_host.upper()}%" if clean_host else "%"
        sql_client = """
        SELECT s.sid, s.serial#, s.status, s.machine, s.osuser, s.program,
               s.event, s.seconds_in_wait, s.blocking_session, s.sql_id,
               b.machine as blocker_machine, b.osuser as blocker_osuser,
               b.program as blocker_program, b.sql_id as blocker_sql_id,
               b.event as blocker_event
        FROM v$session s
        LEFT JOIN v$session b ON s.blocking_session = b.sid
        WHERE s.type <> 'BACKGROUND'
          AND (
            (:h <> '%' AND UPPER(s.machine) LIKE :h)
            OR (:ip <> '' AND (s.client_info = :ip OR UPPER(s.machine) LIKE '%' || :ip || '%'))
          )
        ORDER BY s.seconds_in_wait DESC
        """
        cursor.execute(sql_client, {"h": host_pattern, "ip": clean_ip})
        rows = cursor.fetchall()

        for r in rows[:10]:
            sess_item = {
                "sid": r[0],
                "serial": r[1],
                "status": r[2],
                "machine": r[3],
                "osuser": r[4],
                "program": r[5],
                "wait_event": r[6],
                "wait_seconds": r[7],
                "blocking_sid": r[8],
                "sql_id": r[9],
            }
            if r[8]:  # Has blocking session!
                diag["is_blocked"] = True
                diag["blocker"] = {
                    "blocker_sid": r[8],
                    "blocker_machine": r[10],
                    "blocker_osuser": r[11],
                    "blocker_program": r[12],
                    "blocker_sql_id": r[13],
                    "blocker_event": r[14],
                    "blocked_event": r[6],
                    "wait_seconds": r[7],
                }
            diag["client_sessions"].append(sess_item)

        # If blocker SQL ID is found, query the exact SQL statement text
        if diag.get("blocker") and diag["blocker"].get("blocker_sql_id"):
            bsql_id = diag["blocker"]["blocker_sql_id"]
            try:
                cursor.execute(
                    "SELECT sql_text FROM v$sql WHERE sql_id = :sqid AND rownum = 1",
                    {"sqid": bsql_id},
                )
                sql_row = cursor.fetchone()
                if sql_row and sql_row[0]:
                    diag["blocker"]["blocker_sql_text"] = sql_row[0].strip()[:240]
            except Exception:
                pass

        # 2. Query system-wide global root blockers (sessions currently blocking others)
        sql_global = """
        SELECT b.sid, b.machine, b.osuser, b.program, b.event, b.sql_id, COUNT(*) as blocked_count
        FROM v$session s
        JOIN v$session b ON s.blocking_session = b.sid
        WHERE s.blocking_session IS NOT NULL
        GROUP BY b.sid, b.machine, b.osuser, b.program, b.event, b.sql_id
        ORDER BY blocked_count DESC
        """
        try:
            cursor.execute(sql_global)
            for gr in cursor.fetchall()[:5]:
                diag["global_blockers"].append({
                    "blocker_sid": gr[0],
                    "machine": gr[1],
                    "osuser": gr[2],
                    "program": gr[3],
                    "event": gr[4],
                    "sql_id": gr[5],
                    "blocked_count": gr[6],
                })
        except Exception:
            pass

        # Build concise brief for 7B LLM and human engineers
        if diag["is_blocked"] and diag.get("blocker"):
            b = diag["blocker"]
            sql_hint = f", SQL: {b.get('blocker_sql_text', b.get('blocker_sql_id'))[:80]}" if b.get("blocker_sql_text") or b.get("blocker_sql_id") else ""
            diag["brief"] = (
                f"【核心DB锁阻断】终端会话被会话 SID={b['blocker_sid']} (用户={b['blocker_osuser']}, "
                f"机器={b['blocker_machine']}, 程序={b['blocker_program']}) 阻塞 {b['wait_seconds']}s "
                f"(等待事件: {b['blocked_event']}{sql_hint})"
            )
        elif diag["client_sessions"]:
            top = diag["client_sessions"][0]
            if top.get("wait_seconds", 0) > 3 and top.get("wait_event") != "SQL*Net message from client":
                diag["brief"] = f"终端会话 SID={top['sid']} 正在等待: {top['wait_event']} ({top['wait_seconds']}s)"
            else:
                diag["brief"] = f"终端会话正常 (SID={top['sid']}, 状态={top['status']})"
        elif diag["global_blockers"]:
            gb = diag["global_blockers"][0]
            diag["brief"] = (
                f"全院当前存在全局锁头: SID={gb['blocker_sid']} (用户={gb['osuser']}, 机器={gb['machine']}) "
                f"正在阻塞 {gb['blocked_count']} 个业务会话"
            )
        else:
            diag["brief"] = f"Oracle核心库状态正常 (无会话阻塞, 延迟={latency_ms}ms)"

    except Exception as e:
        diag["error"] = str(e)
        diag["brief"] = f"Oracle查询异常: {str(e)[:100]}"
    finally:
        try:
            conn.close()
        except Exception:
            pass

    return diag


def main():
    p = argparse.ArgumentParser(description="HIOps Oracle Read-Only Diagnostic Tool")
    p.add_argument("--test", action="store_true", help="Test connection and print banner")
    p.add_argument("--ip", default="", help="Client IP address to diagnose")
    p.add_argument("--host", default="", help="Client hostname to diagnose")
    p.add_argument("--proc", default="", help="Client process name")
    args = p.parse_args()

    print(f"Connecting to Oracle {ORACLE_HOST}:{ORACLE_PORT}/{ORACLE_SERVICE} as {ORACLE_USER}...")
    res = diagnose_client_oracle(ip=args.ip, host=args.host, proc_name=args.proc, timeout=4.0)
    print(json.dumps(res, ensure_ascii=False, indent=2))
    print("\nDIAGNOSTIC BRIEF:")
    print(res.get("brief"))


if __name__ == "__main__":
    main()
