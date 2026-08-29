# 测试策略与框架选型

> 编制：程基岩（engineering-lead）｜TASK-10｜服务对象：EPIC-1 至 EPIC-7（垂直切片 126h）
> 结论先行：**手工冒烟清单为骨架，GUT 9.x 为自动化承载，GdUnit4 为备选**。框架两周内不强制落地，先把 E1-S2/S3 验收标准跑绿。

---

## 1. 为什么"手工清单优先"

三条项目现实，决定测试策略不能照搬"正经团队"做法：

1. **单人 + 每周 5-10h**：任何要求装插件、配命令行、学断言 DSL 的方案，第一周就会因为占掉做游戏的时间而被抛弃。
2. **切片内"可测的纯逻辑"极少**：四大系统里只有 SceneRouter 校验、EventBus 信号、战斗纯函数（EPIC-3 起）值得自动化。视觉、手感、y-sort 遮挡（E1-S4/S5 验收项）本质上只能人眼验证——机器判断不了"站着像不像在墙后"。
3. **Godot 新手**：冒烟清单的每一条步骤，同时是 Godot 调试器（输出面板、远程场景树、断点）的上手教材——测试本身在学习路线 C2 的延长线上。

因此本仓库的测试形态：**E1 期间手工执行清单（`smoke/SMOKE-CHECKLIST.md`）→ E2 起把清单逐条搬进 GUT 自动化**。清单条目结构与 GUT 测试函数一一对应，搬迁是体力活不是重写。

## 2. 框架选型（自动化落地用）

### 2.1 主推荐：GUT（Godot Unit Test）9.3.x

- **4.x 分支现状**：GUT 9.x 主动支持 Godot 4，9.2.0+ 明确兼容 4.2/4.3；4.3 稳定版下社区广泛使用，无阻塞性 issue。项目不升 4.4 前不用碰任何兼容开关。
- **选择理由（按本项目优先级排序）**：
  1. **低仪式感**：测试脚本继承 `GutTest`，一个 `func test_xxx():` 就是一条用例，无装饰器、无嵌套 describe——对写惯 jest 的前端思维几乎没有迁移成本。
  2. **安装可推迟**：GUT 安装方式是"从 AssetLib 或 GitHub release 解压到 `res://addons/gut/`+ 开插件"，纯项目内目录，不污染全局、不装任何系统依赖——正好匹配"框架两周内不落地"的排期。缺点是它要进 git（体积 ~几 MB，可接受）。
  3. **文档生态最厚**：Godot 单测问答 90% 指向 GUT，新手搜得到答案。
  4. 信号测试直接用 `watch_signals()` + `assert_signal_emitted_with_parameters()`，正好覆盖 EventBus 用例。
- **局限（先记录，不回避）**：只支持 GDScript（本项目全 GDScript，无影响）；无独立 CLI（需带编辑器运行——单机项目可接受）；参数化测试语法不如 GdUnit4 简洁（本切片用不到参数化）。

### 2.2 备选：GdUnit4 v5.x（不选它的唯一原因是重）

- 4.3 兼容：明确支持，且自带独立 CLI runner（`runtest.sh`），CI 友好。
- 适合它的情形：切片结束后上正式版、需要 GitHub Actions 持续集成时——届时测试资产可从 GUT 平移（断言 API 高度同构），不必现在为"未来的 CI"付学习成本。
- **不推荐新手第 3 周就用的原因**：模板命令、CLI 安装、目录扫描约定都是额外概念；本项目切片内没有 CI 需求，选它属于超前建设。

### 2.3 明确排除：自写断言脚本 / Godot 4.5+ 内置测试框架

- 自写 = 又造一个轮子还要自测它，违背 A1"为 90h 产能设计"。
- Godot 官方测试框架随 4.5 起逐步可用（`scripting/test` 一族），但项目基线钉在 4.3，**不升引擎不追新 API**（引擎一致性铁律）。

### 2.4 落地时点与安装命令（先备忘，到点执行）

- **何时装**：EPIC-2 开工前（W3），装完立刻把 SMOKE-CHECKLIST 里 SMK-01~06 搬成自动化。
- **怎么装**：编辑器内 AssetLib 搜 "GUT" 安装（或 GitHub `bitwes/Gut` release 9.3+ 解压到 `res://addons/gut/`）→ 项目设置→插件→启用 → 编辑器底部出现 GUT 面板 → 创建 `.gutconfig.json`。
- **怎么跑**：编辑器内 GUT 面板点 "Run All"；命令行 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`。
- **GUT 用例骨架（与冒烟清单条目对应）**：
  ```gdscript
  # tests/unit/test_scene_router.gd
  extends GutTest
  # 对应 SMOKE-CHECKLIST 的 SMK-07/08
  func test_reject_invalid_payload_and_log() -> void:
      var result: Dictionary = SceneRouter._validate_payload("battle", {})
      assert_false(result.ok, "空 payload 必须被拒绝")
  ```

## 3. 冒烟测试范围界定

| 范围 | 立场 | 原因 |
|---|---|---|
| Autoload 注册与边界、EventBus 六信号、SceneRouter payload 校验、GameData 纯数据 | **测（首批，见清单）** | 纯逻辑、出错即全线崩、可完全自动化 |
| 战斗结算纯函数（damage_calc / 行动队列） | 测，EPIC-3 起接入 | 架构 A2：core/ 不进场景树，天然可单测；直接服务数值平衡 12h |
| 存档 schema 读写（EPIC-4 起） | 测 round-trip（写→读→字段一致） | ADR-3 的版本化承诺需要回归保障 |
| 视觉/像素锐利度/y-sort 遮挡/手感/移速 | **不测**，走 Story 验收标准人眼验证 | 机器判不了"像不像空轨"，自动化性价比为负 |
| 帧率/性能 | 切片不设测试 | 单机 2D 无热路径（ADR-1 裁定） |
| UI 布局回归 | 不测 | 30 分钟切片，UI 改动频率低 |

**一条红线**：不为了"让某东西可测"而改变架构（例如给 GameData 加 getter/setter 包装）——测试服务架构，不是反过来。

## 4. 目录结构

```
tests/
├── README.md                 # 本文件
└── smoke/
    └── SMOKE-CHECKLIST.md    # 首批冒烟用例（手工可执行，12 条内）
    └── evidence/             # 手工冒烟截图/控制台日志存档（每条 PASS 留一图）
        └── (E1-S2 完成后放入 autoload_tree.png 等)

# EPIC-2 起 GUT 落地后新增：
# tests/unit/     # GutTest 脚本，从冒烟清单迁移 + core/ 纯函数单测
# .gutconfig.json # 仓库根
```

evidence/ 目录规则：文件名 = 用例 ID 小写（如 `smk-01.png`）；一张图或一段控制台粘贴即可，不写报告。

## 5. 与 E1-S1/S2/S3 的挂接方式

测试不是"开发完补的"，是 Story 验收的执行工具：

| Story | 冒烟清单覆盖 | 执行时点 | 绿的标准 |
|---|---|---|---|
| E1-S1 环境与项目骨架 | 无专属用例 | — | 验收标准原文（全屏锐利/截图/git） |
| E1-S2 四 Autoload 空壳 | SMK-01 ~ SMK-06 | **S2 编码完成、勾验收标准前必须全绿** | 全部 PASS 并在 evidence/ 留档；用例不过 = Story 不算完 |
| E1-S3 Main + Router | SMK-07 ~ SMK-10 | 同上，S3 验收前必须全绿 | 同上 |
| 任何后续改动 Autoload/Router 的 Story | 重跑相关条目 | 改动提交前 | 无回归（原有 PASS 不变 FAIL） |

**两条硬规矩**（对齐 production/README 第 5 节验收流程）：

1. **何时必须绿**：对应 Story 勾验收标准之前；以及 M1 里程碑门收口时（试玩视频 #1 录制前）全量重跑一遍——12 条手工用例约 15 分钟，是对抗"改 A 坏 B"的唯一廉价手段。
2. **何时可欠账**：探索性 spike（学习教程时的临时脚本）允许不跑；但一旦代码合入 `autoload/` 或 `scripts/core/`，欠账清零。

**向后衔接**：E1-S2/S3 的验收证据（evidence/ 截图）同时是 Story 四要素里"测试证据"的首次实例；EPIC-2 GUT 落地后，SMK-01~10 逐条转为 `tests/unit/` 自动化用例，原清单保留为"框架坏掉时的人工后备"。

## 6. 风险备忘

- GUT 与 Godot **4.4+** 的兼容以 release notes 为准——若项目将来升 4.4，先跑一遍 GUT 全量用例再合入（升级本身是另一个 ADR 的事）。
- 冒烟清单覆盖的是"架构合同"（A3/A4/A5），不覆盖战斗正确性——战斗合同由 EPIC-3 的 core/ 单测接手，勿在冒烟层加战斗用例。
- 手工清单的风险是"忘跑"：靠第 5 节两条硬规矩 + 里程碑门收口全量重跑兜底，不引入额外工具。
