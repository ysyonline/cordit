# E4-S8 inventory 入存档 schema（version bump 1→2 + 迁移）—— 验证证据

> 角色：engineering-lead 程基岩 · Sprint 4 追加 · P0
> 引擎：Godot 4.7.2 stable（winget 包）+ GUT 9.7.1 · 测试基线 258 → **266**（全绿）
> 需求依据：E4-S5 复验发现的真产品缺口（ADR-3 v1 九冻结字段无 inventory）+ 用户拍板单开 Story
> 环境命令同 E4-S5（evidence/e4s5-chests-investigate.md §2）：
>
> ```
> MSYS2_ARG_CONV_EXCL="*" <Godot_console.exe 全路径> --headless --path . \
>   -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/gut -ginclude_subdirs -gexit
> ```
>
> 本机 Godot 全路径：`C:\Users\weixufeng\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`

---

## 1. 验收结论

| 验收标准 | 结果 | 证据 |
|---|---|---|
| ① 存→读→inventory 无损往返（多道具多数量） | ✅ | test_e4s8 test_01/02/03/07/08 |
| ② v1 旧档（无 inventory 键）读档不报错、inventory 为空、不污染其余字段 | ✅ | test_e4s8 test_04/05/06 |
| ③ GUT 全量零回归（基线 258/258） | ✅ | `evidence/e4s8-gut-s8.log`：**266/266 PASS**，6674 asserts，`All tests passed!`，exit 0 |

---

## 2. 文件变更清单

| 文件 | 变更 |
|---|---|
| `autoload/save_manager.gd` | ① `SCHEMA_VERSION` 1→2；② SCHEMA 加 `"inventory": {}`（十字段）；③ `_migrate` 追加 `if v < 2` 分支（补空 Dictionary，见 §3）；④ `_snapshot` 加 `inventory = GameData.inventory.duplicate()`；⑤ `_restore` 加逐键重建（`String(item_id) → int(count)`，见 §4） |
| `tests/gut/test_e4s8.gd` | 新增 8 用例（往返 3 + 迁移 3 + 落盘结构 1 + 端到端 1） |
| `tests/gut/test_e4s1.gd` | 结构锚同步 v2：test_01 十字段 + `SCHEMA_VERSION == 2`（ADR-3 v1 时代断言已过时） |
| `tests/gut/test_e4s5.gd` | test_12 存档闭环升级 v2 口径：读档后 inventory 从存档无损回灌（v1 时断言为 0 的边界已消除），扰动值被存档值替换 |
| `docs/architecture/godot4-architecture-adr.md` | ADR-3 决策正文同步：schema 示例 v2 十字段 + 迁移注记（ADR checklist 义务："加字段同步改 schema"） |

**未触碰**：`game_data.gd`（inventory 字段 v1 时代已声明，运行时无需改）、chest/investigate 模板（E4-S5 产物零改动）、原子写路径（`_atomic_write` 原样）。

---

## 3. 迁移分支行为说明（_migrate v1→v2）

```
v = data.get("version", -1)
v > 2          → 拒绝读入（未来版本，GameData 不动）——既有守卫不变
v < 1          → v0 占位分支（不变）
v < 2 (新增)   → 补 inventory。实现为"空操作 + 语义注记"：
                 下方 merged 合并逻辑以 SCHEMA（已含 inventory: {}）为底、
                 data 已有键覆盖——旧档缺 inventory 键自然落默认空 Dictionary，
                 已有九字段原样保留。
v == 2         → 直接合并
最终 merged["version"] = 2（上迁标记）
```

设计取舍：
- **为什么 v1→v2 分支是 pass 而不是显式补键**：v1→v2 的结构变换恰好只是"加一个带默认值的字段"，与 `_migrate` 尾部既有的"缺失字段按 SCHEMA 默认补齐"合并逻辑完全重合。分支保留为空壳 + 注记，是给未来"结构变换型"迁移（如 flags 数组→带值字典）占位，同时守住"v 从小到大逐级上迁"的规程形态（E4-S1 迁移承诺原文）。
- **旧档玩家体验**：读 v1 档 → 背包为空（v1 档本来就没有背包数据，语义无损）→ 再存档即落 v2 十字段（test_05 验证"旧档无感升级"）。不存在数据丢失窗口。

---

## 4. 回灌类型安全（_restore 逐键 int 化）

JSON 规范里数字解析恒为 float：`JSON.parse_string('{"a": 2}')` 得 `{"a": 2.0}`。若直接 `GameData.inventory = data["inventory"]`，count 全变 float——后续 `chest.gd` 的 `int(get(...)) + count` 累加虽然能跑，但任何与 int 字面量的字典比较、debug 面板显示、掉落表对账都会分型出错。

`_restore` 现按 `inv[String(item_id)] = int(count)` 逐键重建，test_02 用 `is int` 断言锁死该契约。整体替换 Dictionary 对象安全（战斗侧 `set_inventory` 注入是值拷贝——`_m3_battle_host.gd` 逐条重建 Array，无悬挂引用面）。

---

## 5. 测试覆盖（test_e4s8.gd，8 用例）

| # | 用例 | 断言要点 |
|---|---|---|
| 1 | 存读往返_背包多道具多数量无损 | 3 道具 3 数量；扰动后回灌；扰动值不残留（验收①） |
| 2 | 回灌count恒为int非float | `is int` 类型断言（§4 契约锚） |
| 3 | 空背包往返与二存二读稳定 | 空包无损；二存二读不漂移；last_loaded 指最新档 |
| 4 | v1旧档读档不报错且inventory补空 | 手工构造真实形态 v1 档（九字段+version=1）；不报错、背包空、六组字段原样回灌、version 上迁（验收②） |
| 5 | v1旧档再存档升级为v2带inventory | 旧档→读→拿道具→再存：落盘 v2 含 inventory（无感升级） |
| 6 | v1旧档部分字段缺失仍可读 | 手改档容错延续（缺 inventory+chests_opened 等照读） |
| 7 | v2快照键集等于SCHEMA且inventory为JSON对象 | 键集 ≡ SCHEMA（十字段）；inventory 以对象落盘 |
| 8 | 开箱存读道具数量无损 | chest 模板 `on_interact()` 产品级走法：E4-S5 遗留缺口端到端闭环 |

过程记录：test_05 首跑红（JSON float vs int 字典直比分型判异——E4-S5 test_09 同款教训），改逐键 int 比较后绿；实现代码未因此改动。

既有测试同步（两处，均为 v1 时代断言过时而非行为回归）：
- test_e4s1 test_01：九字段/版本 1 → 十字段/版本 2（结构回归锚随 ADR-3 演进）。
- test_e4s5 test_12：读档后 inventory 断言从 0（v1 不回灌）升级为 2（v2 无损回灌）+ 扰动值清场断言。

---

## 6. 遗留风险与边界

| # | 事项 | 说明 |
|---|---|---|
| ① | 真实旧档实测 | GUT 用 `_write_raw` 构造 v1 档覆盖了全部迁移分支；仓库不存在真实 v1 玩家档（切片开发期），无实测样本。若发布前需要，可临时把 save.json 手写为 v1 形态实机验证一次 |
| ② | SMK-12 静态口径 | smoke 检查记录过"仅 SCHEMA_VERSION=1"（evidence/smk-*.log 为历史留痕），SMK-12 脚本本体不校验版本号数值（已核对 headless_smk.gd 无相关断言），version bump 不触发 smoke 红灯 |
| ③ | gold 字段未入档 | `GameData.gold` 恒为 0（GDD 裁决切片无商店），不入存档；未来开商店时随 version bump v2→v3 处理，维持"GameData 新字段必问进不进存档"的 ADR checklist |
| ④ | headless 退出期 RID WARNING | 历 Sprint 基线即有（10016 orphans 全部来自 battle_ui 历史用例），与本 Story 无关，不阻塞 |

---

## 7. 交付物索引

- schema v2 + 迁移分支：`autoload/save_manager.gd`
- GUT 新用例：`tests/gut/test_e4s8.gd`（8 条）
- 全量回归日志：`evidence/e4s8-gut-s8.log`（266/266，All tests passed!）
- ADR 同步：`docs/architecture/godot4-architecture-adr.md` ADR-3 段
- 本文档：`evidence/e4s8-inventory-save.md`
- **未执行任何 git commit**（环境纪律，待放行）
