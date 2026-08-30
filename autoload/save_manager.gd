extends Node
## SaveManager —— 存读档单例（Autoload 注册名：SaveManager）
##
## 职责边界（架构文档 A3 表）：
##   定义"什么状态可存"的快照协议（schema）；读写单存档槽。
##   不决定何时存——存档时机由事件脚本（save_point 动作）/ UI 通过
##   EventBus.save_requested 触发；进图自动存档由地图侧 map_ready 后调用。
##
## E4-S1 完整实现（EPIC-4，ADR-3：JSON 手写字段序列化，不用 Resource 序列化）：
##   save(map, position)        → 快照 GameData + 调用方提供的地图/位置 → 原子写 user://save.json
##   load_save() -> bool        → 读档 → version 迁移 → 回灌 GameData
##   has_save() -> bool         → 存档存在性（E4-S6/S7 与主菜单用）
##   last_loaded                → 最近一次成功读档的完整快照（E4-S7 失败读档
##                                需要其中 map/position 回图；不经 GameData 中转）
##
## 快照协议（ADR-3）：只存"游戏状态的值"，绝不存场景/节点引用；
## version 字段负责未来迁移（E5/E6 加字段一律走 version bump + _migrate 追加分支）。

## 存档槽路径（单存档槽；user:// 映射到用户数据目录）
const SAVE_PATH: String = "user://save.json"

## 存档格式版本（读档时据此走迁移函数；当前唯一版本）
const SCHEMA_VERSION: int = 1

## 可存状态快照的 schema（与 ADR-3 字段表一一对应，SMK-12 验收依据）：
##   version                  → int，格式版本
##   map                      → String，当前场景路径/地图标识
##   position                 → Array[float, float]，玩家回置点（x, y）
##   party                    → Array，三人队伍快照（等级/HP/MP/装备/道具等）
##   story_phase              → int，剧情阶段
##   flags                    → Array，全局剧情标志（运行时在 GameData.flags 为 Dictionary，序列化时转数组）
##   chests_opened            → Array，已开宝箱集合（GameData.chests_opened）
##   discovered_weakness_set  → Array，已记忆弱点集合（GameData.discovered_weakness_set）
##   cleared_enemy_set        → Array，已击破敌人集合（GameData.cleared_enemy_set）
## 值为各字段的"类型示例占位"（空容器/零值），仅描述结构，不含数据。
const SCHEMA: Dictionary = {
	"version": 1,
	"map": "",
	"position": [0.0, 0.0],
	"party": [],
	"story_phase": 0,
	"flags": [],
	"chests_opened": [],
	"discovered_weakness_set": [],
	"cleared_enemy_set": [],
}

## 角色记录类型（与 GameData 同款 preload 引用，headless 通道即时可用）
const CharacterRecord := preload("res://scripts/core/character_record.gd")

## 存档实际读写路径（默认 = SAVE_PATH）。
## 允许覆写是为 GUT 用例隔离：测试指向独立 user:// 文件，不污染真实存档槽
## （SMK-12 口径：非存档操作不得在 user:// 产生文件）。生产代码不得覆写。
var save_path: String = SAVE_PATH

## 最近一次成功读档的完整快照（E4-S7 失败读档据此回图；读档失败不修改旧值）
var last_loaded: Dictionary = {}


# ---------------------------------------------------------------- 存档

## 存档：快照 GameData + 调用方提供的 map / position → JSON 原子写。
## map/position 由调用方（地图侧 map_ready、事件脚本 save_point）提供，
## 因为它们是节点侧状态，GameData 按职责边界不持有。
## 返回 true = 落盘成功；false = 写入失败（旧档保持不动）。
func save(map: String, position: Vector2) -> bool:
	var snapshot: Dictionary = _snapshot(map, position)
	var text: String = JSON.stringify(snapshot, "\t")
	return _atomic_write(save_path, text)


## 存档存在性（真实存档槽或有测试覆写路径）
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


# ---------------------------------------------------------------- 读档

## 读档：读文件 → JSON 解析 → version 迁移 → 回灌 GameData。
## 返回 true = 回灌成功；false = 文件缺失/损坏/格式未来版本（GameData 不动）。
func load_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false   # 无存档：不算错误，调用方走"首次启动"分支
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: 存档文件存在但无法打开（%s）" % save_path)
		return false
	var text: String = f.get_as_text()
	f = null   # 释放句柄
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveManager: 存档不是合法 JSON 对象（%s）" % save_path)
		return false
	var data: Dictionary = _migrate(parsed as Dictionary)
	if data.is_empty():
		return false   # 未来版本格式：拒绝读入，GameData 不动
	_restore(data)
	last_loaded = data
	return true


## 版本迁移：只上迁、不降迁。返回 {} 表示"无法迁移"（未来版本，拒绝读入）。
## E5/E6 加字段的操作规程（ADR-3 承诺）：
##   1. SCHEMA 加字段（含默认值）→ 2. SCHEMA_VERSION += 1
##   → 3. 在下方追加 `if v < 2: ...` 迁移分支（旧档补默认值/结构变换）
##   → 4. GUT 补一条迁移用例。
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", -1))
	if v > SCHEMA_VERSION:
		push_warning("SaveManager: 存档版本 %d 高于当前支持 %d，拒绝读入" % [v, SCHEMA_VERSION])
		return {}
	if v < 1:
		# v0 → v1：占位分支（当前无历史版本，进入即视为 v1 处理）。
		pass
	# E5/E6 迁移分支追加处（保持 v 从小到大逐级上迁）
	# 缺失字段按 SCHEMA 默认值补齐（容错手改存档/半截字段），已有字段原样保留
	var merged: Dictionary = SCHEMA.duplicate(true)
	for key: String in merged.keys():
		if data.has(key):
			merged[key] = data[key]
	merged["version"] = SCHEMA_VERSION
	return merged


## 回灌：快照字典 → GameData（逐字段显式写，不整对象替换——类型化字段安全）。
func _restore(data: Dictionary) -> void:
	GameData.story_phase = int(data["story_phase"])
	# flags：JSON 键数组 → Dictionary（键集合，值恒 true——切片内标志只有"有/无"语义，
	# 带值标志属未来扩展，届时走 version bump）
	var flags: Dictionary = {}
	for k: Variant in data["flags"]:
		flags[String(k)] = true
	GameData.flags = flags
	GameData.chests_opened = _to_string_array(data["chests_opened"])
	GameData.discovered_weakness_set = _to_string_array(data["discovered_weakness_set"])
	GameData.cleared_enemy_set = _to_string_array(data["cleared_enemy_set"])
	GameData.party = _deserialize_party(data["party"])
	# 注意：map / position 不写 GameData（职责边界），经 last_loaded 供 E4-S7 回图


# ---------------------------------------------------------------- 序列化

## GameData + 调用方参数 → 快照字典（字段集 ≡ SCHEMA 键集）
func _snapshot(map: String, position: Vector2) -> Dictionary:
	var snap: Dictionary = SCHEMA.duplicate(true)
	snap["version"] = SCHEMA_VERSION
	snap["map"] = map
	snap["position"] = [position.x, position.y]
	snap["party"] = _serialize_party(GameData.party)
	snap["story_phase"] = GameData.story_phase
	snap["flags"] = GameData.flags.keys()
	snap["chests_opened"] = GameData.chests_opened.duplicate()
	snap["discovered_weakness_set"] = GameData.discovered_weakness_set.duplicate()
	snap["cleared_enemy_set"] = GameData.cleared_enemy_set.duplicate()
	return snap


## 队伍快照：CharacterRecord → 纯值字典（8 字段，与 E2-S4 写回字段同构）
func _serialize_party(party: Array[CharacterRecord]) -> Array:
	var out: Array = []
	for c: CharacterRecord in party:
		out.append({
			"id": c.id, "name": c.name, "job": c.job, "level": c.level,
			"hp": c.hp, "max_hp": c.max_hp, "mp": c.mp, "max_mp": c.max_mp,
		})
	return out


## 队伍回灌：纯值字典数组 → 重建 CharacterRecord（类型化数组逐元素 append，
## 规避 Array[CharacterRecord] 直接赋值的类型坑）
func _deserialize_party(arr: Array) -> Array[CharacterRecord]:
	var out: Array[CharacterRecord] = []
	for pd: Dictionary in arr:
		out.append(CharacterRecord.new(
			String(pd.get("id", "")), String(pd.get("name", "")), String(pd.get("job", "")),
			int(pd.get("level", 1)), int(pd.get("hp", 1)), int(pd.get("max_hp", 1)),
			int(pd.get("mp", 1)), int(pd.get("max_mp", 1))))
	return out


## 字符串集合回灌（逐元素 String 化，防御 JSON 数字混入）
func _to_string_array(arr: Array) -> Array:
	var out: Array = []
	for v: Variant in arr:
		out.append(String(v))
	return out


# ---------------------------------------------------------------- 原子写

## 原子写（探索 GDD §3.4 工程义务）：先写临时文件，全部落盘后 rename 替换。
## 任一步失败：删除临时文件（尽力而为）、返回 false、旧档原封不动。
## "写入中途强杀进程旧档可读出"由此保证——旧档在被 rename 前从未被触碰。
func _atomic_write(path: String, text: String) -> bool:
	var tmp_path: String = path + ".tmp"
	# ① 写临时文件
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: 临时文件写入失败（%s），旧档保留" % tmp_path)
		return false
	f.store_string(text)
	f.flush()
	f = null   # 释放句柄确保落盘关闭，rename 才不会因文件占用失败
	# ② rename 替换旧档（DirAccess.rename 对同目录操作是原子替换语义）
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		_cleanup_file(tmp_path)
		push_warning("SaveManager: 存档目录无法打开（%s），旧档保留" % path.get_base_dir())
		return false
	var err := dir.rename(tmp_path.get_file(), path.get_file())
	if err != OK:
		_cleanup_file(tmp_path)
		push_warning("SaveManager: rename 失败（err=%d），旧档保留" % err)
		return false
	return true


## 尽力而为删除文件（清理临时文件的兜底，失败不追责）
func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
