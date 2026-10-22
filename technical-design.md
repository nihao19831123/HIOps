# CriticalCare-Agent Gym 详细技术设计方案

> 急危重症抢救多智能体自主沙盒 —— 动态生理病理仿真 + LangGraph 状态图 + 指南 DAG 质控 + 反事实推演
>
> 版本：V1.2（2026-09-06，基础 P-001~P-008 + 纵深增强 E-001~E-005 全部落地）
> 状态：与 `backend/src/ccg` / `frontend/src` 当前代码一致（120 pytest 全绿 + 前端 build + 浏览器 E2E 验证）
> 配套执行计划：`docs/loopx/plans/2026-09-06-criticalcare-gym.md`（P-*）、`docs/loopx/plans/2026-09-06-ccg-enhance.md`（E-*）

---

## 目录

1. [项目定位与设计目标](#1-项目定位与设计目标)
2. [总体架构](#2-总体架构)
3. [核心设计决策与安全不变式](#3-核心设计决策与安全不变式)
4. [生理状态机引擎（core/engine）](#4-生理状态机引擎coreengine)
5. [临床剧本场景（core/scenarios）](#5-临床剧本场景corescenarios)
6. [指南 DAG 质控（core/qc）](#6-指南-dag-质控coreqc)
7. [多模态信号引擎（core/multimodal）](#7-多模态信号引擎coremultimodal)
8. [多智能体编排（agents/）](#8-多智能体编排agents)
9. [异步动作调度与资源竞争（core/dispatch）](#9-异步动作调度与资源竞争coredispatch)
10. [闭环医嘱与澄清（agents/readback）](#10-闭环医嘱与澄清agentsreadback)
11. [反事实因果推演（core/counterfactual）](#11-反事实因果推演corecounterfactual)
12. [Gymnasium 标准接口（gym_api）](#12-gymnasium-标准接口gym_api)
13. [后端 API 与实时会话（api/）](#13-后端-api-与实时会话api)
14. [前端抢救室中控台（frontend/）](#14-前端抢救室中控台frontend)
15. [数据与事件模型](#15-数据与事件模型)
16. [测试策略与验证证据](#16-测试策略与验证证据)
17. [运行部署与演示剧本](#17-运行部署与演示剧本)
18. [已知边界与后续路线图](#18-已知边界与后续路线图)

---

## 1. 项目定位与设计目标

### 1.1 定位

面向住培医生急救考核、急救竞赛现场演示与急救 AI 研究的**动态数字孪生急救室沙盒**。核心差异点：

- **不是**静态文字问答：病情随时间流逝、动态恶化，支持多模态信号（ECG/检验）协同；
- **不是**大模型自由发挥：生理数据由本地数学状态机**唯一裁决**，模型不得捏造生命体征；
- **不是**单 agent 聊天：完整急救团队协同（主管医生/责任护士/患者/家属），并受物理动作延迟与抢救室人手资源约束；
- **不是**模糊打分：质控把临床指南编译成 DAG，输出可解释的拓扑偏离与时序延误指标；失败结局自动反事实推演"平行宇宙"对比。

### 1.2 设计目标（验收总纲）

| 目标 | 验收 |
|---|---|
| 医学严谨性 | 生理数值演化由本地引擎保证一致性（低氧→代偿→灌注不足→乳酸↑→意识↓），模型只做语言层 |
| 演示张力 | 氯化钾推注等危险医嘱 100% 被护士拦截（本地规则，不依赖 LLM）；等待期病情持续恶化 |
| 实时性 | WS 推送体征/波形/任务进度；真实时间×5 加速，病情可见速度演化 |
| 可解释性 | DAG 质控偏离分 + Time-to-Antibiotics 等时序窗口 + What-If 反事实双曲线 |
| 稳定性 | 断网/无 key 演示不中断（语言层降级模板）；120 自动化测试护航 |
| 标准化 | Gymnasium 接口封装，支持后续多模型竞技评测 |

### 1.3 技术栈

| 层 | 选型 |
|---|---|
| 后端语言 | Python 3.11（uv 包管理，阿里云镜像源） |
| 后端框架 | FastAPI + Uvicorn + WebSocket |
| 编排框架 | LangGraph（StateGraph 显式图拓扑） |
| 数值/信号 | NumPy（ECG 波形合成） |
| LLM | OpenAI 兼容端点（默认 DeepSeek `api.deepseek.com/v1`），无 key 降级本地模板 |
| 前端 | React 18 + Vite + TypeScript + Tailwind CSS v4（单页三栏中控台） |
| 测试 | pytest（120 tests）+ npm build + 浏览器 E2E 冒烟 |

### 1.4 非目标（明确不做）

- 真实医疗设备/医院系统接入；临床决策支持（本系统为培训/竞赛/研究演示，非诊疗用途）；
- 多患者并发、大规模水平扩展（单机单会话现场演示架构）；
- 真实采集 ECG（波形为形态学可辨识的参数化合成）；
- 本阶段集成 Pulse/BioGears 等 C++ 生理内核（见 §18 路线图 defer 项）。

---

## 2. 总体架构

```
┌────────────────────── 本地轻量化环境（普通 PC） ──────────────────────┐
│                                                                        │
│  [真实时间时钟 ×5 加速]                                                 │
│       │ tick(dt)                                                       │
│       ▼                                                                │
│  ┌──────────────────────────────┐      ┌──────────────────────────┐   │
│  │  临床剧本场景 Scenario         │      │  异步动作调度 TaskScheduler│   │
│  │  (sepsis / stemi_vf)          │◄────►│  Action Latency + 人手模型│   │
│  │  注入病理进程·触发时间线事件     │      │  到期回调引擎副作用          │   │
│  └──────────┬───────────────────┘      └──────────┬───────────────┘   │
│             ▼                                     │ on_due=apply_order│
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │  PhysiologyEngine 生理状态机（数值唯一权威）                        │ │
│  │  状态向量 [HR,SBP,DBP,SpO2,Lactate,GCS] + 隐藏变量(K,pH,缺血,感染,氧债)│ │
│  │  氧合·灌注·乳酸·意识·心律失常·骤停/死亡 演化；PK/PD 药物效应           │ │
│  └───────────────────────────────▲──────────────────────────────────┘ │
│       快照/事件                    │ 医嘱(复诵后)                       │
│        ▼                          │                                  │
│  ┌───────────────────────────────┴───────────────────────────────┐   │
│  │ LangGraph 多智能体 StateGraph                                  │   │
│  │  红线门(本地规则) → 闭环复诵 → 澄清(剂量/途径模糊) → 调度/执行       │   │
│  │  ├ 患者 Agent（受 GCS/状态硬约束）   ├ 护士 Agent（复诵/拦截/反馈）   │   │
│  │  └ 家属 Agent（情绪压力随抢救升级）                                 │   │
│  └───────────────────────────────┬───────────────────────────────┘   │
│       结构化事件流 EventBus        │ 医嘱/动作                         │
│        ▼                          ▼                                  │
│  [多模态引擎 ECG 波形/检验]   [指南 DAG 质控]   [反事实推演 What-If]    │
│        │                        │              │（失败结局自动）       │
│        └──────────┬─────────────┴──────────────┘                     │
│                   ▼                                                  │
│        FastAPI + WebSocket 会话层（单会话单机）                        │
└───────────────────┬──────────────────────────────────────────────────┘
                    │ 只发送结构化状态与指令（JSON）
                    ▼
        [公网强推理 LLM API（DeepSeek 等）—— 语言层，可关/可降级]
```

**关键分层原则**：数值（引擎）→ 时序（场景/调度）→ 决策约束（红线/质控）→ 语言表达（LLM）→ 呈现（前端）。上层只能读取/调用下层，禁止上层伪造下层数据。

---

## 3. 核心设计决策与安全不变式

### 3.1 五项安全不变式（有回归测试锁定，禁止破坏）

1. **红线拦截同步先行**：违禁医嘱（route=iv 归一 + 推注同义词表）由 `RedlineEngine` 本地规则**立即**拦截，绝不进入执行/任务队列；被拦截医嘱只经 `engine.record_violation()` 登记。
2. **生理状态机是数值唯一权威**：agent 不得捏造数值；异步任务到期仅回调 `engine.apply_order` 施加效应。
3. **测试不许红**：任何"语义改变"（如 E-001 把同步执行改为延迟执行）只允许改变执行时机，不允许取消效应或破坏既有 84+ 测试语义。
4. **LLM 失败/断网一律降级本地中文模板**：演示不中断；LLM 只做语言层（复诵、澄清、反馈、复盘长文）。
5. **职责隔离**：红线/复诵/质控/调度各有独立模块，拦截绝不进入执行逻辑，复用现有消息/事件结构。

### 3.2 关键架构决策记录

| 决策 | 理由 | 落点 |
|---|---|---|
| 生理引擎 = 本地确定性离散 tick 数学，非 LLM 输出 | 模型自由发挥会"上一秒休克下一秒正常"，失去医学严谨性 | §4 |
| LLM 仅语言层、可整体关闭 | 现场演示保底；key 缺失/网络抖动不影响核心流程 | §8.4 |
| 时钟 ×5 加速（虚拟秒/现实秒） | 病情在观众可感知速度演化（5 分钟容错期≈1 分钟现实） | §4.1 |
| 医嘱默认异步（dispatch=True） | 真实抢救非秒执行：配药/按压/除颤有物理耗时；医生须在等待窗口决策 | §9 |
| 护士红线独立于引擎 | 引擎红线只是护士规则真子集的兜底；拦截话术 100% 稳定不靠模型 | §8.2 |
| 指南→DAG + 时序窗口 | 质控可解释：路径偏离分 + 超时延误分钟，而非笼统打分 | §6 |
| 反事实用同进程深拷贝回滚 | 单机演示无需多进程；RNG 深拷贝后同轨、干预后真实分叉（已测） | §11 |
| Gym 无硬依赖 | `gymnasium` 缺失时纯接口可用；安装后注册 `CriticalCareGym-v0` | §12 |

---

## 4. 生理状态机引擎（core/engine）

### 4.1 时钟（clock.py）

`VirtualClock(time_scale=5.0)`：`advance(real_seconds)` 返回虚拟秒增量并累加。默认 1 现实秒 = 5 虚拟秒；前端倒计时按 5 倍折算显示现实秒。

### 4.2 状态向量（types.py / engine/state.py）

**可见向量**（VitalSigns dataclass，`as_dict()` 输出）：

| 字段 | 含义 | 默认 |
|---|---|---|
| hr | 心率 bpm | 75 |
| sbp / dbp | 收缩/舒张压 mmHg | 120/80 |
| spo2 | 血氧饱和度 % | 98 |
| lactate | 乳酸 mmol/L | 1.0 |
| gcs | 格拉斯哥昏迷评分（整数 3-15） | 15 |
| rr / temp | 呼吸频率 / 体温 | 16 / 36.8 |
| rhythm | 心电节律标签（SR/ST-elev/VT/VF/PEA/ASY） | SR |
| consciousness | 意识描述（清醒/嗜睡/昏睡/昏迷，由 GCS 推导） | 清醒 |
| etco2 / map | 呼气末 CO₂（插管后）/ 平均动脉压（计算） | — |

**隐藏变量**（HiddenPhysiology，不对模型暴露、由引擎掌控）：血钾 k、动脉血 pH、组织氧债 oxygen_debt、感染负荷 infection_burden、心肌缺血 ischemia、出血量 bleeding。

**行为旗标**（PhysiologicalStateWrapped）：iv_line / oxygen / ventilated / compression_assist / alive / rosc / redline_violations / flags / defib_count。

### 4.3 演化规则（physiology.py 核心 tick）

`PhysiologyEngine.advance(dt)` 每 tick 顺序执行：

1. **氧合（_step_oxygenation）**：已给氧/通气 → SpO2 向 97-100 回升；未给氧 → 容错期（默认 300 虚拟秒 = 5 分钟，可配）后 SpO2 按 `spo2_drift_per_min`（默认 2%/min）下降，<94% 触发反射性心率代偿，<85% 乳酸爬升，<60% 持续报警濒临骤停。
2. **灌注（advance 内联）**：MAP = DBP + (SBP−DBP)/3；MAP < 阈值（默认 65）→ 氧债累积、乳酸按 `lactate_rise_per_min` 上升；恢复灌注 → 氧债 1/5 偿还、乳酸按 dt/240 清除。
3. **缺血与心律失常（_step_ischemia_rhythm）**：ischemia>0.35 → ST-elev（波形层体现）；缺血>0.55 起 VT 风险 = f(缺血程度 × 低钾系数)，低灌注概率翻倍；VT→VF 概率随缺血升高；**缺血>0.92 确定性转 VF**（保证"不处理必死"剧情）；除颤成功清除 vf_forced 允许再发。
4. **意识（_step_consciousness）**：目标 GCS 由 SpO2/MAP/节律联合推导，平滑逼近后取整；≤8 昏迷，患者 agent 只能无意识呻吟。
5. **按压辅助循环**：无自主搏动 + 按压中 → MAP 维持 ≈55（人工循环）。
6. **骤停/死亡**：MAP<40 概率转 PEA；VF/VT/PEA/ASY 无按压持续 >240 虚拟秒 → 引擎级死亡（`_death_by_prolonged_arrest`），按压期间计时清零。
7. **钳制（_clamp）**：HR∈[0,220]、SBP∈[0,260]、SpO2∈[30,100]、乳酸∈[0.3,20]、k∈[1.5,8]、pH∈[6.8,7.6]，DBP 不得超过 SBP×0.6。

### 4.4 PK/PD（pkpd.py）

`DrugProfile`：达峰 t_peak / 半衰期 t_half / 效应系数（hr/sbp/dbp/k/ph）/ 是否允许静推 iv_push_allowed / 静推剂量上限。药典含：肾上腺素（静推 1mg）、去甲肾上腺素（禁推，微泵）、胺碘酮、阿托品、氯化钾（**禁推红线药**）、碳酸氢钠、多巴胺、头孢哌酮舒巴坦/哌拉西林他唑巴坦/美罗培南/万古霉素（抗生素，感染控制由场景旗标驱动）、阿司匹林/氯吡格雷。

`DrugInBody.effect_at(now)`：单次给药浓度曲线 = 上升段线性到峰 + 指数衰减（`concentration_at`）。当前引擎直接效应采用单次叠加近似（E-001 后经任务调度在到期时刻施加）；体内浓度池模型保留供后续微分方程接入。

### 4.5 医嘱施加（apply_order / record_violation）

- `record_violation(order)`：护士层拦截后的**纯登记**（绝不执行）。
- `apply_order(order)`：引擎侧红线兜底（禁推药 route=iv 无条件拦、剂量上限）→ 命中则登记并返回 `REDLINE:` 事件；放行则给药（`_apply_drug_effects` 按 route 折算：静推全效、静滴 1/4 持续）或处置（`_apply_intervention` 关键词路由：通路/给氧/插管/补液/除颤/CPR）。
- 除颤成功（双向波 85% 转复）→ 自动 `declare_rosc()`（恢复 SR、hr≥70、gcs=14、清除 vf_forced）。
- `declare_death()`：alive=False、GCS=3、恶性节律转 ASY。

---

## 5. 临床剧本场景（core/scenarios）

### 5.1 场景抽象（base.py）

`Scenario`：构建引擎（`_build_engine`）+ 初始体征（`_initial_vitals`）+ 时间线剧本事件（`_register_script`，ScenarioEvent{at, text, fn}）+ 每 tick 病理注入（`_extra_tick`，**基类统一调用恰好一次**）+ 结局判定（`_good/_bad_outcome_condition`）+ 家属压力（family_pressure 随时间/恶化升 0-1）。

**注意**：`_extra_tick` 由 `base.tick` 统一调用——子类覆写 tick 时不得再自行调用（曾有双跑 bug，已有回归测试按单 tick 增量速率断言）。

### 5.2 场景① 急性下壁 STEMI → 室颤骤停（stemi_vf）

- 初始：HR 96 / 128/76 / SpO2 97 / 乳酸 2.1 / ST-elev / 血钾 3.2（利尿剂致低钾诱因）。
- 缺血爬升（灌注好 ~0.055/min，灌注差 0.16/min）→ ST 弓背抬高 → 频发室早 → 缺血>0.92 确定性 VF。
- 正确路径：氧 + 心电图 + 心梗三项 + 阿司匹林负荷 + 监护除颤仪就位 + **再灌注决策（mark_reperfused：PCI/溶栓）**；VF 时按压 + 双向波除颤 → ROSC。
- 好结局 = ROSC 后心律稳定 + **已再灌注** + 缺血<0.45，持续 90 虚拟秒（防"被动等 VF 单次除颤"取巧）。
- 坏结局：15 虚拟分钟无 ROSC；或 ROSC 后 20 分钟未再灌注缺血再发死亡；引擎级无循环 240s 死亡。
- 剧本事件：0s 胸痛/ST 弓背，60s 家属冲入，240s 频发室早预警。

### 5.3 场景② 脓毒症休克 · SSC 集束化（sepsis）

- 初始：HR 122 / 88/52 / SpO2 90 / 乳酸 3.8 / GCS 13 / 39.2℃ / 感染负荷 0.6。
- 感染增殖（未用抗生素 ~0.0009/s 至顶）→ 血管扩张级联：血压下拉速度 ∝ 感染负荷 × 灌注缺口（MAP 越低塌得越快）；液体复苏（fluid_ok）与升压药（vaso_on）反制。
- 正确路径（SSC 1h bundle）：给氧 + 培养 + 乳酸 + **广谱抗生素（abx_on，30s 起效延迟后感染指数下降）** + 晶体液 + 去甲肾上腺素微泵。
- 好结局 = 抗生素已用 + 感染<0.15 + SBP≥100 + 乳酸<2.5，持续 120 虚拟秒。
- 坏结局：顽固性低血压（SBP<48 且 MAP<36）；18 分钟未用抗生素且不达标；**30 虚拟分钟硬超时**（杜绝升压药无限顶血压拖延）。
- 剧本事件：0s 识别+启动集束化，90s 家属质疑/要求转院，300s 血压下降意识昏睡。

### 5.4 场景对象关系

```
Scenario (场景实例, 单会话持有)
 ├── engine: PhysiologyEngine        ← 本场景专属引擎（含 hidden/state）
 ├── events[]: ScenarioEvent          ← 时间线剧本
 ├── outcome: Outcome|None            ← 结局(ok/label/reason/elapsed)
 ├── family_pressure: float
 └── conversation_log[]
```

---

## 6. 指南 DAG 质控（core/qc）

### 6.1 DAG 模型（dag.py）

`GuidelineDag{name, nodes: DagNode{id,label,window_min,critical}, edges}`：构造时校验节点引用完整 + **环检测**（DFS 三色法）。

### 6.2 内置指南（guidelines.py）

**脓毒症休克 SSC 集束化**（窗口=虚拟分钟，演示 1h≈10 虚拟分钟）：

```
recognition(0,crit) → cultures(5,crit) → abx(10,crit) ─→ source_ctrl(40)
recognition ────────→ fluids(15,crit) ─────────────→ vasopressor(25) → reassess(50)
```

**急性心梗 AHA 处置**：

```
ecg10(3,crit) → recognition(5,crit) → asa(5) ──────────→ reperfusion(15,crit)
ecg10 ────────→ monitor(3,crit) → arrhythmia(1,crit)     recognition ─→ k_correction(10)
```

### 6.3 评分（scorer.py）

`QcScorer.note_action(node_id, ts, text)` 记录操作命中；`report(now)` 输出：

- **拓扑偏离**：每完成节点检查父节点——父未做（跳步）+1 偏离、父后做（逆序）+1；
- **覆盖度**：关键节点完成比例；
- **时序偏差**：关键节点完成相对入口的虚拟分钟 vs window_min → delay_min 列表；
- **偏离分**：跳步/逆序 15 分/次 + 关键未做 20 分/个 + 超窗 10 分/个（0=完美 100=严重）；
- **延误曲线**：delay_curve（沿时间轴未完成关键节点数，前端画质控趋势）。

---

## 7. 多模态信号引擎（core/multimodal）

### 7.1 ECG 波形合成（ecg.py）

`rhythm_pattern(rhythm, hr, st_offset_mm)` 参数化合成单心动周期采样（numpy）：P-QRS-T 高斯模板；**ST-elev** 弓背向上（QRS 后缓升后陡升上凸段，偏移随缺血量 `(ischemia-0.35)×4 mm`）；**VT** 宽大畸形 QRS（宽 90ms）；**VF** 杂乱高频低幅（0.35×5.2Hz 调制）；**PEA** 极弱电活动；**ASY** 直线。

`EcgSynth.next_window(seconds)` 输出 `[[x_ms, y], ...]` 供前端 Canvas 滚动；`lead_cycle` 12 导联幅值差异（胸导 V1-V6 放大）。**波形永远由引擎状态驱动，不经 LLM**。

### 7.2 检验生成（labs.py）

`LabEngine.generate(hidden, vitals)`：乳酸（H>2.0）、血钾（L<3.5/H>5.5）、动脉血气 pH、肌钙蛋白 I（0.03+ischemia×4）、CRP、WBC——数值与状态机一致，随时可开具。

---

## 8. 多智能体编排（agents/）

### 8.1 LangGraph 图拓扑（langgraph_flow.py + graph.py）

编译为真实 `StateGraph`（业务单一事实来源在 graph.py 的 step_* 方法，图节点逐一委托）：

```
__start__ → gate(红线裁决,同步)
              ├─blocked→ block(登记violation+护士高危警报+家属惊动) → END
              └─pass→ verify(闭环复诵/澄清 E-002)
                         ├─clarify(挂起待补全) → END
                         └─readback→ execute(同步 apply_order 或 E-001 schedule)
                                       → nurse(反馈) → patient(反应) → END
```

图中节点薄封装 handler 的 `step_gate/step_block/step_verify/step_execute/step_nurse/step_patient`，保证"拓扑换壳、业务不重写"。执行异常自动线性降级（演示不中断）。

### 8.2 护士红线引擎（redline.py）

本地确定性规则，优先级序：

| 规则 | 判定 | 拦截 |
|---|---|---|
| 氯化钾静推 | drug==氯化钾 且 route=="iv"（**无条件，与 rate 无关**） | danger：严禁静推，须稀释微泵缓滴 |
| 途径限制 | 药典 iv_push_allowed=False 且 route=="iv" | danger：改微泵静滴 |
| 剂量上限 | route=="iv" 且 dose > max_iv_push_dose | warn |
| 过敏史 | 场景注入 allergies，药名命中 | warn |
| 低血压禁忌 | 硝普钠/硝酸甘油 + SBP<90 | warn |

**措辞归一**：order_parser 把"静注/静推/静脉注射/静脉推入/缓慢推注/直接推/iv push/iv bolus…"全部归一 route="iv"（PUSH_SYNONYMS 正则），杜绝同义措辞绕过。氯化钾微泵（ivdrip）放行。

### 8.3 各角色约束

- **患者 Agent**：system prompt 绑定当下生命体征 JSON，铁律"生理数据唯一权威"；昏迷(≤8)只能无意识呻吟；不懂术语，只描述感受。
- **护士 Agent**：口头医嘱复诵制度（E-002）、违禁医嘱坚决拦截并给纠正建议、数值以快照为准。
- **家属 Agent**：pressure<0.3 焦虑询问 / 0.3-0.6 催促质疑 / >0.6 哭闹崩溃要求转院；可能按剧本试探性透露隐瞒病史。

### 8.4 LLM 客户端（llm.py）

`LlmClient.chat/chat_json`：OpenAI 兼容端点（DeepSeek 默认），超时/无 key/解析失败一律抛 `LlmError` → 上层 `speak_*` 降级 `template_speech`/本地模板。**LLM 输出永不回流为数值**。

---

## 9. 异步动作调度与资源竞争（core/dispatch）

### 9.1 Action Latency 库（latency.py）

`ACTION_LATENCY`（虚拟秒）：建立静脉通路 120 / 面罩给氧 30 / 气管插管 180 / 补液 500ml 90 / 抽血 60 / 配药+静推 90 / 除颤 45 / 心电图 120 / 血培养 60。`duration_for(order)`：drug 默认 90s，intervention 按关键词，复合取最大。`hands_for(order)`：CPR=2 手持续，其余 1 手。`is_continuous(order)`：CPR。

### 9.2 TaskScheduler（scheduler.py）

任务生命周期：`queued（等人手）→ running（占手执行/倒计时）→ done（到期回调）`。

- `schedule(order, hands, duration, on_due)`：人手够 → 直接 running（有限任务 due_at=now+duration，持续任务 duration=None 占手至 finish）；人手不足 → queued + `needs_question=True`（护士质询/排队）。
- `tick(dt, now)`（时钟线程每 tick 调，**RLock 线程安全**）：①放行能容纳的排队任务（重新计时）→ ②持续任务首 tick 施加效应（CPR 立即生效语义）→ ③到期任务回调 `on_due(=engine.apply_order)` 标 done 释放人手。
- `finish(task_id)`：提前结束持续任务/取消排队任务，释放人手。
- `running` 摘要 dict：`{now, busy_hands, nurse_hands, tasks:[{id,order,kind,phase,hands,due_at,remaining,note}]}`（前端双手占用条/倒计时数据源）。

### 9.3 与现有语义的衔接（session.py）

- `ResuscitationSession(dispatch=True)`：构造 scheduler 注入 graph；`_run_loop` 每 tick 调 `_dispatch_tick(dt)` → scheduler.tick → 到期任务广播 `GraphMessage(kind='task_done')`；SNAPSHOT 事件 payload 附 `nursing=scheduler.running`。
- dispatch=False 时 graph 走原同步路径（向后兼容测试/教学）。
- **除颤中断按压**（E-002 语义）：除颤医嘱到达 → scheduler.finish(运行中 CPR) + `engine.state.compression_assist=False` + 广播 task_interrupt → 除颤 1 手 45s 入队。

---

## 10. 闭环医嘱与澄清（agents/readback）

`build_readback(order)`：药嘱「肾上腺素 1mg 静脉推注，确认执行」/处置「{处置}，确认执行」（本地模板，LLM 注入可选）。

`completeness_check(order) → list[str]`：药嘱无剂量（dose≤0）、无途径（route 空/默认 ivdrip 但原文无滴注词）、处置无动词命中 → 缺失项列表。

`resolve_clarify(reply, original)`：复用 `order_parser._match_unit/route_from_text` 合并新剂量/途径（保留原 order id）。`looks_like_clarify_reply` 判定下一条消息是否补全回复。

**流程图**（graph.step_verify_order）：红线放行 → 完整性检查 → 缺失 → 广播 `kind=clarify` 质询并置 `pending_clarify`（不调度）；完整 → 广播 `kind=readback` 复诵 → 进入执行/调度。session.submit_order 对 pending_clarify 且新文本像补全 → resolve 后继续；不同药名则按新医嘱（防误路由）。

**闭环示例**：

```
[医生] 静注肾上腺素 1mg！
[护士·readback] 肾上腺素 1mg 静脉推注，确认执行！
[护士·task_started] 收到，开始执行（约 90 秒后完成）
...
[护士·task_done] 已执行完成：静注肾上腺素 1mg
```

---

## 11. 反事实因果推演（core/counterfactual）

### 11.1 Checkpointer（checkpointer.py）

`capture(scenario)`：深拷贝场景（engine+scenario 一体）。**RNG 同轨已验证**：拷贝后 random 状态一致，两世界独立推进即真实分叉（节律分化 VT vs ST-elev 实测）。scheduler 含 RLock 不可深拷贝 → capture 仅场景，反事实重放用同步语义（graph dispatch=False）重建队列。

### 11.2 分叉点提取（forks.py）

从事件时间线提取（最多 3 个，按致命度排序）：①相邻医嘱 gap≥60 虚拟秒且期间恶化（SpO2↓/SBP↓/乳酸↑）；②关键 DAG 节点时限临期（如抗生素窗口前 30s）仍未执行。产出 `ForkPoint{t, reason, suggested_actions:[order_text]}`。

### 11.3 best-response 预案（best_response.py）

sepsis：给氧+培养+乳酸+广谱抗生素+补液+去甲微泵；stemi_vf：给氧+心电图+心梗三项+阿司匹林+监护+再灌注 PCI +（VF 则按压+除颤）。文本全部经 order_parser 可解析。

### 11.4 WhatIfEngine（engine.py）

对每个 fork：restore checkpoint → 重放实际后续记 actual_tail → 再 restore → 施加 suggested_actions（同步 graph）→ 快进同窗口记 counterfactual_tail → 比较 SBP/乳酸/存活。输出双轨迹各 ≤40 点 `{t,sbp,spo2,lactate,alive}` + narrative。

### 11.5 复盘接入（session.debrief）

`debrief()` 仅当结局 ok=False 时运行反事实推演（好结局为空数组）；每 fork 重放 ≤120 虚拟秒×2 超时保护；失败静默降级空列表，不影响复盘主流程。**实测**：脓毒症未治死亡 → 3 分叉点，反事实干预 SBP 73.4→96.7、存活 False→True。

---

## 12. Gymnasium 标准接口（gym_api）

### 12.1 动作空间（actions.py）

`ACTION_SPACE`：13 项离散动作（给氧/通路/心电图/培养+乳酸/广谱抗生素/补液/去甲微泵/氯化钾微泵/除颤/CPR/肾上腺素静推/心电监护/**氯化钾 20ml 静推陷阱**）；连续参数：dose_mult(0.5/1/2) + 输液速率。`DISCRETE_SIZE=13`。

### 12.2 环境（env.py）

`CriticalCareGymEnv`（duck-typing gym.Env，无硬依赖）：

- `reset() → obs`：新建场景（同步 graph），返回结构化 obs（hr/sbp/dbp/spo2/lactate/gcs/rhythm/consciousness/map + 近 3 事件文本）；
- `step(action_id, dose_mult=1.0) → (obs, reward, done, info)`：动作 → parse_order + graph.handle_order（红线/复诵/澄清原生处理）→ 内部按 1 虚拟秒粒度推进 step_virtual_s；
- **奖励** = 0.5·ΔMAP/80 + 0.2·ΔSpO2/100 + 0.3·(−Δ乳酸/4) + DAG 关键节点首次 +5 − 每步 0.05；好结局 +100 / 死亡 −100；
- 执行成功医嘱才记 DAG 节点并接治疗旗标（复刻 session 语义）；被拦截医嘱只 record_violation；
- 可选：`gymnasium` 存在则继承并 `register(id="CriticalCareGym-v0")`；缺失纯接口可用。

---

## 13. 后端 API 与实时会话（api/）

### 13.1 REST 端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | /api/health | 健康检查 |
| GET | /api/scenarios | 场景列表（id/title/brief/patient/family） |
| POST | /api/session/start | 启动会话 `{scenario_id, seed?, llm_enabled, dispatch=True}` |
| POST | /api/session/{sid}/order | 医生医嘱 `{text}` → `{messages[], snapshot, outcome?}` |
| GET | /api/session/{sid}/events?cursor= | 增量事件轮询（WS 断线兜底） |
| GET | /api/session/{sid}/ecg?lead=&seconds= | ECG 波形点 |
| GET | /api/session/{sid}/labs | 检验报告 |
| POST | /api/session/{sid}/debrief | 终止并复盘（含 counterfactual） |
| WS | /ws/{sid} | 实时流：snapshot/ecg/event/over |

### 13.2 会话管理器（session.py）

`ResuscitationSession`：装配 scenario + graph + flow + qc scorer + scheduler + EventBus + LLM；后台时钟线程 `_run_loop`（tick_hz=2 现实/s，每 tick 推进 dt_virtual=0.5×time_scale）：场景 tick → 调度器 tick → 快照/事件入 bus → 客户端增量拉取。医嘱入口 `submit_order`：解析（`_parse_or_resolve` 澄清路由）→ 红线门（拦截即返）→ QC 节点映射+治疗旗标接线 → flow.run → 消息入 bus。

### 13.3 医嘱解析（order_parser.py）

药名**长度降序**匹配（防"去甲肾上腺素"被子串"肾上腺素"误配）+ 剂量单位正则 + 推注同义词归一 + 滴速解析（每小时 N ml / N ml/h / N 滴分）；处置关键词表（12 类含 monitor/troponin 映射）；`infer_qc_nodes` 一条医嘱可命中多 DAG 节点（"抽血培养+查乳酸"→cultures+recognition）。

---

## 14. 前端抢救室中控台（frontend/）

### 14.1 布局（三栏）

```
┌──────────────────────────────────────────────────────────────────────────┐
│ ⚡ CRITICALCARE-AGENT GYM   · 动态生理仿真·多智能体·DAG质控   T+123s LIVE │
├──────────────────────┬──────────────────────────┬─────────────────────────┤
│ 生命体征监护(左)      │ 抢救指令台(中)            │ 上帝视角·质控与复盘(右)  │
│ ┌──────────────────┐ │ ┌──────────────────────┐ │ ┌─────────────────────┐ │
│ │ ECG Canvas 滚动   │ │ │ 护士 🧑⚕ 1/2手占用   │ │ │ 指南 DAG 质控       │ │
│ │ (SR/ST/VF 波形    │ │ │ ⏱ 83s ≈17s 倒计时    │ │ │ 偏离分0·覆盖100%    │ │
│ │  随引擎状态变色)   │ │ │ ┌──────────────────┐ │ │ │ ✓节点✓✓✓✓          │ │
│ ├──────────────────┤ │ │ │[主管医生]📋医嘱    │ │ │ ├───────────────────┤ │
│ │ HR 132 bpm        │ │ │[责任护士]🔊复诵    │ │ │ │ 实时趋势 SBP/HR/   │ │
│ │ NIBP 85/51 MAP62  │ │ │[责任护士]▶任务开始 │ │ │ │ SpO2/Lac 曲线      │ │
│ │ SpO2 87%  RR 28   │ │ │[患者]含混呻吟      │ │ │ ├───────────────────┤ │
│ │ Lac 4.8 GCS 10    │ │ │[家属]哭喊质疑       │ │ │ │ 检验报告          │ │
│ ├──────────────────┤ │ ├──────────────────────┤ │ ├───────────────────┤ │
│ │ 输液泵/氧/通气状态│ │ │ 快捷医嘱条+文字/语音  │ │ │ │ 复盘(What-If双曲线 │ │
│ │                  │ │ │ 🎤 下医嘱 下达        │ │ │ │ 实际红 vs 反事实绿 │ │
│ └──────────────────┘ │ └──────────────────────┘ │ └─────────────────────┘ │
└──────────────────────┴──────────────────────────┴─────────────────────────┘
```

### 14.2 组件

| 组件 | 职责 |
|---|---|
| MonitorPane | 左栏：EcgCanvas（Canvas 滚动波形+网格+发光描边+当前时刻线）、VitalsPanel 9 数值块、InfusionPumps、AlarmBanner（红/琥珀脉冲） |
| CommandConsole | 中栏：场景选择+LLM 开关+开始/状态、ChatStream 角色对话流（kind 样式：redline 红警报/readback 蓝绿复诵/澄清琥珀待补全/task_done 绿勾/task_interrupt 中断/order 蓝医嘱）、**护士双手占用条+任务倒计时 chip**、快捷医嘱×12、文字/Web Speech 语音输入、检验/终止复盘按钮 |
| OverviewPane | 右栏：QcPanel（偏离分/覆盖条/节点✓◌/超时警告）、TrendPanel 四路 sparkline、LabsPanel、DebriefPanel、**CounterfactualChart（What-If 卡片：实际红实线 vs 反事实绿虚线 Canvas 叠画、尾点存活标注、转败为生徽标）** |

### 14.3 数据通路（useSession.ts）

WS 常开增量消费事件（snapshot 事件带 nursing）；WS 断开降级 1.5s 轮询 events?cursor。消息双路（POST 响应 + WS 事件）以 **3 秒同文本去重**防重复渲染。会话状态机：vitals/chats/alarms/qc/labs/nursing/over/debrief 集中在 SessionCtl。

---

## 15. 数据与事件模型

### 15.1 事件总线（types.EventBus）

统一事件流 `Event{seq, type, ts_virtual, role, text, payload}`，类型见 §契约——SNAPSHOT/ORDER/AGENT_SAY/ALARM/REDLINE/QC/LAB/ECG/SCENARIO/DEBRIS。**前端与复盘消费同一事件流**（增量游标拉取）。

### 15.2 消息 kind（GraphMessage）

say / redline / readback / clarify / task_started / task_done / task_interrupt / nurse_busy / order。

### 15.3 复盘 JSON（debrief）

```
{
  ok, outcome{ok,label,reason,elapsed},
  timeline[], vitals_history[](≤600抽样),
  qc{done[],pending_critical[],deviation_score,coverage,time_violations[],delay_curve[]},
  narrative,                 // LLM 长文或本地结构化摘要
  counterfactual[]           // [{fork_t,reason,suggested_actions,
                             //   actual_tail[],counterfactual_tail[],survival_delta,narrative}]
}
```

---

## 16. 测试策略与验证证据

### 16.1 测试矩阵（120 pytest 全绿）

| 套件 | 覆盖 |
|---|---|
| test_smoke / engine_physiology | 事件总线/时钟/类型 + 恶化速率、容错期、肾上腺素重置、KCl 红线、clamp、ROSC、死亡演进 |
| test_scenarios | 双场景好坏结局、VF 除颤复苏、只按压不除颤必死、红线标记 |
| test_qc | DAG 环校验、完美路径低偏离、跳步扣分、超窗检出、延误曲线 |
| test_multimodal | 各节律波形特征（ASY 直线/VF 杂乱/ST 抬高/VT 宽 QRS）、检验与状态一致 |
| test_agents | 红线必拦（参数化同义词）、LLM 降级、患者发言绑定 GCS、家属压力、**LangGraph 真图单次执行（防双执行）** |
| test_api | REST/WS 冒烟、KCl 拦截、dispatch 集成（复诵→延迟）、澄清、QC 映射 |
| test_dispatch | 延迟生效、期间引擎演化、人手竞争、持续任务 finish |
| test_readback | 复诵含剂量途径、无剂量→澄清不调度、补全合并、除颤中断按压 |
| test_counterfactual | 死亡案例 ≥1 fork 且反事实存活、好结局为空、restore 一致、真分叉 |
| test_gym_api | reset/step 循环、奖励单调、死亡 -100、KCl 陷阱无副作用、dose_mult |
| test_review_regressions | 独立审查（2026-09-06）全部缺陷回归 |

### 16.2 真实执行验证（非自报）

- 后端 `uv run pytest`：**120 passed**（多次独立复跑）；
- 前端 `npm run build`：无错误；
- 真实 HTTP E2E：双场景自然结局（sepsis 抢救成功 dev 0/覆盖 1.0；stemi 规范成功 dev 0、放任死亡 dev 100）；KCl 拦截；异步延迟 90 虚拟秒后 task_done 且 SBP 88→142；
- 浏览器 E2E：三栏渲染、实时体征、复诵 1 次（去重）、双手占用条 1/2 手 ⏱83s、死亡案例 What-IF 卡片渲染。

---

## 17. 运行部署与演示剧本

### 17.1 启动

```bash
# 后端
cd backend && uv sync --group dev
uv run python -m ccg.api.run            # http://127.0.0.1:8000

# 前端（另终端）
cd frontend && npm install && npm run dev   # http://localhost:5173
```

环境变量（backend）：`CCG_LLM_BASE_URL/API_KEY/MODEL`（默认 DeepSeek，缺省自动模板降级）、`CCG_TIME_SCALE=5`、`CCG_TICK_HZ=2`、`CCG_HOST/PORT`。

### 17.2 演示剧本（现场推荐）

**场景①脓毒症·SSC**：拖延 2-3 分钟看恶化与家属施压 → 陷阱医嘱「10%氯化钾 20ml 推注」被护士拦截（高光）→ 完整医嘱触发**复诵** → 集束化治疗（注意给药有延迟、护士双手占用、人手不足会质询）→ ~2 分钟现实后「抢救成功」，DAG 偏离 0 → 复盘。若要展示 What-If：换一轮故意不救，死亡后复盘区出现红绿双曲线。

**场景②STEMI→VF**：放任 → ST 弓背 → 突发 VF 红色警报 → 不做再灌注只除颤 → 缺血不降再发/超时；规范路径（氧+心电图+心梗三项+阿司匹林+监护+PCI 决策+除颤）→ ROSC 成功。

### 17.3 Gym 快速验证

```python
from ccg.gym_api.env import CriticalCareGymEnv
env = CriticalCareGymEnv("sepsis", seed=1)
obs = env.reset()
obs, r, done, info = env.step(0)   # 动作下标见 actions.ACTION_SPACE
```

---

## 18. 已知边界与后续路线图

### 18.1 已知边界（诚实声明）

- 生理动力学为**竞赛演示级近似**（单次叠加药效、无真实房室模型）；ECG 为参数化合成；非临床决策支持。
- 单机单会话；反事实为同进程回滚（非真多进程）。
- What-If 对临终分叉（如 VF 已发、缺血已满）回滚也救不回——引擎真实语义（太晚干预无效），演示时建议展示早期分叉。
- LLM 现场延迟可能明显；降级模板保证不中断但语气固定。

### 18.2 后续路线图（对应《模拟系统增强》defer 项）

| 方向 | 内容 | 前提/理由 |
|---|---|---|
| 生理引擎升维 | 接入 Pulse/BioGears C++ ODE 内核替换经验公式；状态机"深浅解耦"（引擎后台 10-50Hz 静默运转） | Windows+360 环境引入外部二进制内核风险高；需先在 Linux 容器验证绑定；现有闭环已成立 |
| 多进程反事实 | Checkpoint → 多进程并行推演多个 fork | 当前同进程深拷贝语义等价且快；仅在 >3 fork 或论文 benchmark 场景需要 |
| 竞技评测 | 100 种病例 × 多模型（GPT-4o/Claude/DeepSeek-R1/Qwen）跑 Survival/Adherence/Time-to-ROSC | 需病例库扩充 + 运行期评测脚本（Gym 接口已就绪） |
| 临床细节 | 多模态 POCUS（前负荷/心功能 → 切面动图）、闭环更多科室动作、呼吸机/监护联动 | 增量演进，不破坏现有不变式 |
| 论文包装 | 《CriticalCare-Gym: A Benchmark for …》 | Gym + 评测轨道齐备后 |

---

## 附：目录索引

```
criticalcare-agent-gym/
├── README.md
├── CLAUDE.md / AGENTS.md            # agent 上下文与安全不变式
├── docs/
│   ├── source/design.md             # 原始需求（含增强附件要点）
│   ├── technical-design.md          # 本文档
│   └── loopx/plans/                 # P-001~P-008 与 E-001~E-005 执行计划
├── backend/
│   ├── pyproject.toml               # uv + pytest 配置
│   ├── src/ccg/
│   │   ├── config.py                # 环境变量配置
│   │   ├── core/{engine,scenarios,qc,multimodal,dispatch,counterfactual}/
│   │   ├── agents/{graph,langgraph_flow,llm,prompts,redline,readback}.py
│   │   ├── api/{main,run,schemas,session,order_parser}.py
│   │   └── gym_api/{actions,env}.py
│   └── tests/                       # 120 tests
└── frontend/
    ├── vite.config.ts               # dev proxy → 127.0.0.1:8000
    └── src/{types,api,useSession,App}.ts(x)
        └── components/{MonitorPane,CommandConsole,OverviewPane,CounterfactualChart}.tsx
```
