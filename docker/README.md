# HIOps 医院智能信息运维平台 — Docker 容器化运行指南

本目录包含 HIOps 医院智能信息运维平台的完整容器化编排环境，包含 **PostgreSQL 16 数据库容器** 与 **HIOps Web 控制台 + 核心后端 API 容器**。

---

## 🚀 极速启动与停止

### 方案 A：Windows 桌面双击（推荐）
- **启动服务**：直接双击运行 [`start.bat`](./start.bat) 脚本，容器编排会自动就绪并提示访问地址。
- **停止服务**：直接双击运行 [`stop.bat`](./stop.bat) 脚本。

### 方案 B：命令行启动
```bash
cd docker
docker-compose up -d
```

---

## 🌐 登录与使用信息

- **Web 控制台地址**：[http://localhost:8088](http://localhost:8088)
- **默认管理员账号**：`admin`
- **默认管理员密码**：`Admin@123`

---

## 🏥 平台功能板块一览

进入 Web 控制台后，您可直接体验以下模块：
1. **运行驾驶舱 (`/dashboard`)**：全院门诊、急诊、住院核心系统健康度、实时吞吐量与告警全景；
2. **资产拓扑中心 (`/topology/network` / `/topology/virtualization` / `/business`)**：全院 43+ 台服务资产、虚拟化、接入交换机与全链路业务依赖图谱；
3. **监控与告警中心 (`/monitor/incidents`)**：告警防抖、拓扑依赖抑制、120s 滑动窗口事故单聚合；
4. **患者数据安全与合规 (`/security/dlp`)**：门诊敏感字段脱敏审计、诱饵蜜罐与异常外联阻断；
5. **探针覆盖与网络发现 (`/monitor/coverage` / `/monitor/network`)**：全院 6 大物理隔离网段在线终端与探针覆盖情况。
