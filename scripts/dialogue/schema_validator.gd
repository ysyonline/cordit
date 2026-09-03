extends RefCounted
## schema_validator.gd —— 对话/事件 JSON 的 schema 校验器（E5-S2，对话 GDD §3.1/§3.2）
##
## 【为什么独立成类】E5-S1 时结构校验内联在 DialogueRunner；E5-S2 事件加载器
##   也要同一套"加载期拦截"（边缘 1：悬空引用游戏内不出现），且事件侧要查
##   "dialogue 动作引用的对话脚本本身合法"——两路复用同一口径，抽离为静态
##   纯函数集（零状态、零场景依赖，Refcounted 纯工具类，同 DataTables 定位）。
##
## 【校验器三大职责】（GDD §3.2 工程侧实现约定，本类即其落地）：
##   ① 动作 type 白名单：GDD §3.2 最终清单全量 10 个字面 type（dialogue /
##      give_item / set_flag / battle / heal / teleport / save_point /
##      set_story_phase / wait / play_sfx；表格把 wait/play_sfx 并作一行计
##      "9 种"）。未知 type 报错；GDD §3.2 裁掉的那个旧动作不在白名单、
##      落进来即被拒，字面回归由 test_e5s2 的零字面扫描锁定（含本文件）。
##   ② 引用完整性：dialogue id（含 phase 映射值）/ give_item 的 item_id /
##      battle 的 group（敌方编组 id）全部必须可解析到实际文件/表（边缘 1）。
##   ③ 结构校验：必填字段、conditions 键白名单（仅 story_phase / flag /
##      not_flag 三种，GDD §3.2"不扩展"）、phase 映射键必须字符串数字且至少
##      含 "0" 兜底键。
##
## 【phase 映射】（GDD §3.2 工程约定，E5-S3 消费）：
##   dialogue 动作的 id 允许映射形态 {"0": "dlg_a", "1": "dlg_b"}；选取规则 =
##   取 ≤ 当前 story_phase 的最大键（keys{0,1} 且 phase=2 时选 "1"）。键在
##   加载期规范化为 int（normalize_phase_map）；非数字键报错。
##
## 【加载口】load_dialogue_script（对话单脚本）与 load_events_file（事件文件）
##   是 A7"数据驱动"的本体职责（FileAccess 读 res://，同 dialogue_runner 先例；
##   A3 只约束 autoload 四单例，A1 零 IO 只约束 scripts/core——本类在
##   scripts/dialogue（对话域正本，自 runner 抽离的落点），events 侧跨域引用本类）。
##   加载失败打印原因并返回空字典，调用方拒绝开演/引导。
##
## 【JSON 数字口径】Godot 的 JSON.parse_string 把一切数字解析为 float——校验
##   对"整数语义"的字段（story_phase 值 / give_item.count / set_story_phase.phase）
##   一律先 float 化比对再 int 取值（is_equal_approx / int()），否则合法数据
##   被类型误拒（E5-S2 首轮集成实测踩坑）。

## 对话 JSON 根目录（与 dialogue_runner.DIALOGUE_DIR 同源；runner 侧常量保留
## 供既有引用，新代码一律走本常量）
const DIALOGUE_DIR: String = "res://data/json/dialogues/"

## 动作类型白名单（GDD §3.2 最终清单全量；顺序即文档表格行序）
const ACTION_TYPES: Array[String] = [
	"dialogue", "give_item", "set_flag", "battle", "heal",
	"teleport", "save_point", "set_story_phase", "wait", "play_sfx",
]

## conditions 键白名单（GDD §3.2：仅 3 种键，不扩展）
const CONDITION_KEYS: Array[String] = ["story_phase", "flag", "not_flag"]

## story_phase 条件允许的运算符（切片实际消费：>= 常规、> 严格、== 锚定）
const STORY_PHASE_OPS: Array[String] = [">=", ">", "=="]

## 选项分支尾巴汇合步数上限（GDD §3.4 第 2 条；与 runner 侧常量同值同源）
const BRANCH_TAIL_MAX_STEPS: int = 2

## 数值表（give_item.item_id / battle.group 的引用完整性查表对象）
const DataTables := preload("res://scripts/data/data_tables.gd")


# ------------------------------------------------------------------
# 对话脚本（GDD §3.1）—— 自 E5-S1 DialogueRunner 平移，口径逐字保持
# ------------------------------------------------------------------

## 对话加载口：id → res://data/json/dialogues/<id>.json → 校验 → 条目字典。
## 返回 {} = 拒绝（文件不存在 / 解析错 / 结构非法，原因已打印）。
static func load_dialogue_script(p_id: String) -> Dictionary:
	var path: String = DIALOGUE_DIR + p_id + ".json"
	if not FileAccess.file_exists(path):
		print("[SchemaValidator] 对话文件不存在：%s" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		print("[SchemaValidator] 对话文件为空：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or (parsed as Dictionary).is_empty():
		print("[SchemaValidator] JSON 非法（顶层须为非空字典）：%s" % path)
		return {}
	# 顶层 = { 对话脚本id: { 条目id: 条目 } }；取唯一脚本（GDD §3.1：一个文件=一段对话）
	var script_key: String = (parsed as Dictionary).keys()[0]
	var entries: Dictionary = parsed[script_key]
	var err: String = validate_dialogue_entries(entries, path)
	if not err.is_empty():
		print("[SchemaValidator] 结构校验拒绝（%s）：%s" % [path, err])
		return {}
	return entries


## 对话脚本结构校验。返回空串 = 通过；非空 = 首个拒绝原因。
## 口径：GDD §3.1 字段表 + §3.4 分支规则 + 边缘 1（悬空引用加载期拦截）。
static func validate_dialogue_entries(entries: Dictionary, path: String) -> String:
	if not entries.has("start"):
		return "缺少 start 入口"
	var entry_ids: Array = entries.keys()
	for entry_id: Variant in entry_ids:
		var eid := String(entry_id)
		var entry: Variant = entries[entry_id]
		if typeof(entry) != TYPE_DICTIONARY:
			return "条目 %s 非字典" % eid
		var e := entry as Dictionary
		# 必填字段（GDD §3.1 表：speaker/text 必填；next 必填——但带 choices 的
		# 条目可省略 next：§3.1 完整示例的 start 条目即 choices 无 next，
		# 示例为验收①"原样加载"的权威正本，校验以示例口径为准）
		for req: String in ["speaker", "text"]:
			if not e.has(req):
				return "条目 %s 缺必填字段 %s" % [eid, req]
		if typeof(e["speaker"]) != TYPE_STRING or typeof(e["text"]) != TYPE_STRING:
			return "条目 %s speaker/text 须为字符串" % eid
		var has_choices: bool = e.has("choices") and (e["choices"] is Array) \
				and not (e["choices"] as Array).is_empty()
		if not e.has("next"):
			if not has_choices:
				return "条目 %s 缺必填字段 next（无选项的条目必须有 next）" % eid
		elif typeof(e["next"]) != TYPE_STRING:
			return "条目 %s next 须为字符串" % eid
		else:
			# next：字符串，"END" 或可解析条目（边缘 1）
			var nxt := String(e["next"])
			if nxt != "END" and not entries.has(nxt):
				return "条目 %s next 悬空引用 \"%s\"" % [eid, nxt]
		# 文本超 60 字：只告警（渲染层自动折行，GDD §3.1 不设滚动历史）
		if (e["text"] as String).length() > 60:
			push_warning("[SchemaValidator] 条目 %s 文本 %d 字（>60，渲染层折行）：%s" % [
					eid, (e["text"] as String).length(), path])
		# choices：可选；≤2 项；item.text/next 字符串；next 可解析；禁嵌套 choices
		var choices: Variant = e.get("choices")
		if choices != null:
			if typeof(choices) != TYPE_ARRAY:
				return "条目 %s choices 须为数组" % eid
			var arr := choices as Array
			if arr.size() > 2:
				return "条目 %s choices 数量 %d 超上限 2（GDD §3.4）" % [eid, arr.size()]
			for c: Variant in arr:
				if typeof(c) != TYPE_DICTIONARY:
					return "条目 %s choices 元素须为字典" % eid
				var cd := c as Dictionary
				if typeof(cd.get("text")) != TYPE_STRING or typeof(cd.get("next")) != TYPE_STRING:
					return "条目 %s choices 元素缺 text/next（或非字符串）" % eid
				var cn := String(cd["next"])
				if cn != "END" and not entries.has(cn):
					return "条目 %s choice next 悬空引用 \"%s\"" % [eid, cn]
				if cn != "END" and (entries[cn] as Dictionary).has("choices"):
					return "条目 %s 选项分支内嵌 choices（禁：分支尾巴即选项条目）" % eid
	return validate_branch_convergence(entries)


## 分支汇合校验（GDD §3.4 第 2 条）：每个带 choices 的条目，其各分支尾巴
## 从选项 next 出发沿 next 链走 ≤2 步（含起点条目自身，即尾巴 ≤2 条目）
## 必须到达同一汇合条目——或各自直接 END（汇合点 = 结束）。
static func validate_branch_convergence(entries: Dictionary) -> String:
	for entry_id: Variant in entries.keys():
		var e := entries[entry_id] as Dictionary
		var choices: Variant = e.get("choices")
		if choices == null or (choices as Array).is_empty():
			continue
		var dests: Array[String] = []
		for c: Variant in (choices as Array):
			dests.append(String((c as Dictionary)["next"]))
		# 各分支沿 next 链收集 ≤2 步内的"汇合候选"：到达 END 记 "END"
		var endpoints: Array[String] = []
		for d: String in dests:
			endpoints.append(branch_endpoint(entries, d, BRANCH_TAIL_MAX_STEPS))
		var all_end := true
		for ep: String in endpoints:
			if ep != "END":
				all_end = false
		if all_end:
			continue   # 各自直接 END：合法（GDD 示例即此形态）
		# 否则必须汇合到同一条目
		if endpoints.size() > 1:
			for i: int in range(1, endpoints.size()):
				if endpoints[i] != endpoints[0]:
					return "条目 %s 选项分支 %d 步内未汇合（%s vs %s）" % [
							String(entry_id), BRANCH_TAIL_MAX_STEPS, endpoints[0], endpoints[i]]
	return ""


## 从 start_id 沿 next 链走至多 max_steps 步（含起点 = 第 1 个条目），
## 返回该分支的汇合端点 id；中途遇 END 返回 "END"（防御：加载校验已保证
## 纯文本尾巴无嵌套 choices，不会再分支）。
static func branch_endpoint(entries: Dictionary, start_id: String, max_steps: int) -> String:
	var cur := start_id
	for i: int in max_steps:
		if cur == "END":
			return "END"
		if i == max_steps - 1:
			return cur   # 走满步数：当前条目即汇合候选（尾巴第 max_steps 个条目）
		var e := entries[cur] as Dictionary
		if e.has("choices") and not (e["choices"] as Array).is_empty():
			return cur   # 理论不可达（嵌套 choices 已在结构校验拒绝）；防御返回
		# next 缺省 "END"（带 choices 条目省 next 的 GDD §3.1 示例口径；
		# 此处尾巴条目无 choices，缺 next 即收束）
		cur = String(e.get("next", "END"))
	return cur


# ------------------------------------------------------------------
# 事件（GDD §3.2）—— 结构 / 白名单 / 引用完整性 + phase 映射规范化
# ------------------------------------------------------------------

## 事件文件加载口：路径 → JSON → 校验 → 规范化。
## 返回 {} = 拒绝（原因已打印）；{"skipped": true} = 非事件 schema 文件（E4
## 点位镜像，顶层缺 "events" 键，跳过不计失败）；否则 =
## {"events": {event_id: 事件字典},
##  "phase_maps": {event_id: {动作序号: {int phase: 对话 id}}}}。
static func load_events_file(p_path: String) -> Dictionary:
	if not FileAccess.file_exists(p_path):
		print("[SchemaValidator] 事件文件不存在：%s" % p_path)
		return {}
	var text: String = FileAccess.get_file_as_string(p_path)
	if text.is_empty():
		print("[SchemaValidator] 事件文件为空：%s" % p_path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or (parsed as Dictionary).is_empty():
		print("[SchemaValidator] JSON 非法（顶层须为非空字典）：%s" % p_path)
		return {}
	var root: Dictionary = parsed
	if not root.has("events"):
		# 非 §3.2 事件 schema 文件（E4 的 chests/investigates/teleports 三份
		# 点位镜像）：返回 {"skipped": true} 供加载器与"校验拒绝"区分——
		# 跳过不计失败（load_all 消费此标记）
		print("[SchemaValidator] 跳过非事件 schema 文件（顶层无 events 键）：%s" % p_path)
		return {"skipped": true}
	var events: Dictionary = root["events"]
	# 第一遍：dialogue 引用完整性（含 phase 映射值）——边缘 1 加载期拦截
	for eid: Variant in events.keys():
		var ev: Variant = events[eid]
		if typeof(ev) != TYPE_DICTIONARY:
			print("[SchemaValidator] 事件 %s 非字典：%s" % [String(eid), p_path])
			return {}
		var actions: Variant = (ev as Dictionary).get("actions")
		if typeof(actions) != TYPE_ARRAY:
			continue   # 结构错误留给 validate_event 报首因
		for a: Variant in (actions as Array):
			if typeof(a) != TYPE_DICTIONARY:
				continue
			var act := a as Dictionary
			if String(act.get("type")) != "dialogue":
				continue
			var idv: Variant = act.get("id")
			if typeof(idv) == TYPE_STRING and not dialogue_exists(String(idv)):
				print("[SchemaValidator] 事件引用的对话不存在（%s）：%s" % [String(idv), p_path])
				return {}
	# 第二遍：逐事件结构/白名单/表引用校验 + phase 映射键规范化
	var phase_maps: Dictionary = {}
	for eid: Variant in events.keys():
		var ev: Dictionary = events[eid] as Dictionary
		var eid_s := String(eid)
		var err: String = validate_event(ev, eid_s)
		if not err.is_empty():
			print("[SchemaValidator] 事件校验拒绝（%s）：%s" % [p_path, err])
			return {}
		# phase 映射收集并规范化（键：动作序号 → 值：{int phase: 对话 id}）
		var actions: Array = ev.get("actions", [])
		var pm: Dictionary = {}
		for i: int in actions.size():
			var act: Dictionary = actions[i]
			if String(act.get("type")) == "dialogue" and typeof(act.get("id")) == TYPE_DICTIONARY:
				var norm: Dictionary = normalize_phase_map(act["id"])
				if norm.is_empty():
					print("[SchemaValidator] phase 映射规范化失败（非数字键，%s）：%s 第 %d 动作" % [
							eid_s, p_path, i])
					return {}
				pm[i] = norm
		if not pm.is_empty():
			phase_maps[eid_s] = pm
	return {"events": events, "phase_maps": phase_maps}


## 事件结构校验（三职责落地）。返回空串 = 通过；非空 = 首个拒绝原因。
## 注：dialogue 的字符串 id 是否指向真实文件不在本函数查（res:// 之外的
## 纯结构用法——如单测直驱——不触盘），统一由 load_events_file 第一遍把关。
static func validate_event(p_event: Dictionary, p_event_id: String) -> String:
	# —— conditions：键白名单 + 值结构（GDD §3.2：仅 3 种键，不扩展）——
	var conds: Variant = p_event.get("conditions")
	if conds == null:
		conds = {}
	if typeof(conds) != TYPE_DICTIONARY:
		return "事件 %s conditions 须为字典" % p_event_id
	for k: Variant in (conds as Dictionary).keys():
		var key := String(k)
		if not CONDITION_KEYS.has(key):
			return "事件 %s conditions 键 \"%s\" 不在白名单（仅 %s）" % [
					p_event_id, key, " / ".join(CONDITION_KEYS)]
		var v: Variant = (conds as Dictionary)[k]
		match key:
			"story_phase":
				# 先验容器结构与长度，再取元素（防短数组越界中断校验）
				if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
					return "事件 %s conditions.story_phase 须为 [运算符字符串, 数字]" % p_event_id
				# 元素 0：运算符白名单；元素 1：JSON 通道来的是 float、GDScript
				# 字典直驱（单测）来的是 int——双收，但必须为整数值（2.5 拒）
				if typeof((v as Array)[0]) != TYPE_STRING:
					return "事件 %s conditions.story_phase 须为 [运算符字符串, 数字]" % p_event_id
				var pv: Variant = (v as Array)[1]
				if typeof(pv) != TYPE_FLOAT and typeof(pv) != TYPE_INT:
					return "事件 %s conditions.story_phase 须为 [运算符字符串, 数字]" % p_event_id
				if not is_equal_approx(float(pv), float(int(pv))):
					return "事件 %s conditions.story_phase 须为整数值" % p_event_id
				if not STORY_PHASE_OPS.has(String((v as Array)[0])):
					return "事件 %s conditions.story_phase 运算符 \"%s\" 不在 %s" % [
							p_event_id, String((v as Array)[0]), " / ".join(STORY_PHASE_OPS)]
			"flag", "not_flag":
				if typeof(v) != TYPE_STRING:
					return "事件 %s conditions.%s 须为字符串 flag 名" % [p_event_id, key]
	# —— actions：数组 + 元素字典 + type 白名单 + 按类型必填字段 ——
	var actions: Variant = p_event.get("actions")
	if typeof(actions) != TYPE_ARRAY or (actions as Array).is_empty():
		return "事件 %s 缺 actions 数组（或为空）" % p_event_id
	for i: int in (actions as Array).size():
		var a: Variant = (actions as Array)[i]
		if typeof(a) != TYPE_DICTIONARY:
			return "事件 %s 第 %d 个动作须为字典" % [p_event_id, i]
		var act := a as Dictionary
		var atype := String(act.get("type"))
		# ① 白名单：未知 type 报错（GDD §3.2 裁掉的旧动作落进来即被此行拒绝）
		if not ACTION_TYPES.has(atype):
			return "事件 %s 第 %d 个动作 type \"%s\" 不在白名单（GDD §3.2 最终清单）" % [
					p_event_id, i, atype]
		var err: String = _validate_action_fields(act, atype, p_event_id, i)
		if not err.is_empty():
			return err
	# —— dialogue 映射形态：键规范 + "0" 兜底 + 映射值可解析 ——
	for i: int in (actions as Array).size():
		var act: Dictionary = (actions as Array)[i]
		if String(act.get("type")) != "dialogue" or typeof(act.get("id")) != TYPE_DICTIONARY:
			continue
		var err2: String = _validate_phase_map(act["id"], p_event_id, i)
		if not err2.is_empty():
			return err2
	return ""


## 按动作类型校验必填字段与引用完整性（③ 结构校验 + ② 引用完整性的动作面）。
## wait/play_sfx 按 E5-S2 验收原文允许空实现占位：不设必填字段，参数多带不拒。
static func _validate_action_fields(p_act: Dictionary, p_type: String,
		p_event_id: String, p_idx: int) -> String:
	match p_type:
		"dialogue":
			var idv: Variant = p_act.get("id")
			if typeof(idv) == TYPE_STRING:
				if String(idv).is_empty():
					return "事件 %s 第 %d 个动作 dialogue.id 为空串" % [p_event_id, p_idx]
				# 文件存在性由 load_events_file 第一遍统一查（见函数头注）
				return ""
			if typeof(idv) == TYPE_DICTIONARY:
				return ""   # 映射形态：键规范在 _validate_phase_map
			return "事件 %s 第 %d 个动作 dialogue.id 须为字符串或 phase 映射字典" % [p_event_id, p_idx]
		"give_item":
			var iid := String(p_act.get("item_id", ""))
			if iid.is_empty():
				return "事件 %s 第 %d 个动作 give_item 缺 item_id（字符串）" % [p_event_id, p_idx]
			# 引用完整性：须可解析到道具表（DataTables.ITEMS，E3-S1 同源）
			if DataTables.get_item(iid) == null:
				return "事件 %s 第 %d 个动作 give_item.item_id 不可解析（道具表查无）：%s" % [
						p_event_id, p_idx, iid]
			# JSON 数字恒为 float：count 先 float 化验收（正且整），再落 int（见头注口径）
			var count_v: Variant = p_act.get("count")
			if typeof(count_v) != TYPE_FLOAT and typeof(count_v) != TYPE_INT:
				return "事件 %s 第 %d 个动作 give_item.count 须为正整数" % [p_event_id, p_idx]
			if float(count_v) < 1.0 or not is_equal_approx(float(count_v), float(int(count_v))):
				return "事件 %s 第 %d 个动作 give_item.count 须为正整数" % [p_event_id, p_idx]
			return ""
		"set_flag":
			if String(p_act.get("flag", "")).is_empty():
				return "事件 %s 第 %d 个动作 set_flag 缺 flag 名（字符串）" % [p_event_id, p_idx]
			return ""
		"battle":
			var gid := String(p_act.get("group", ""))
			if gid.is_empty():
				return "事件 %s 第 %d 个动作 battle 缺 group（敌方编组 id）" % [p_event_id, p_idx]
			# 引用完整性：须可解析到敌方编组表（DataTables.ENCOUNTERS，A5 查表对象）
			if DataTables.get_encounter(gid) == null:
				return "事件 %s 第 %d 个动作 battle.group 不可解析（编组表查无）：%s" % [
						p_event_id, p_idx, gid]
			return ""
		"heal":
			return ""   # 全回复语义，无参数
		"teleport":
			var to_map := String(p_act.get("to_map", ""))
			if to_map.is_empty():
				return "事件 %s 第 %d 个动作 teleport 缺 to_map" % [p_event_id, p_idx]
			var spawn: Variant = p_act.get("to_spawn")
			if typeof(spawn) != TYPE_ARRAY or (spawn as Array).size() != 2:
				return "事件 %s 第 %d 个动作 teleport 缺 to_spawn [x, y]" % [p_event_id, p_idx]
			for e: Variant in (spawn as Array):
				if typeof(e) != TYPE_FLOAT and typeof(e) != TYPE_INT:
					return "事件 %s 第 %d 个动作 teleport.to_spawn 元素须为数字（可含 .5 半格）" % [
							p_event_id, p_idx]
			return ""
		"save_point":
			return ""   # 无参数：向 SaveManager 发存档请求
		"set_story_phase":
			# 目标阶段缺省 0（三个切换点事件各自钉死阶段，E5-S3/S4 接线时
			# 由事件名语义决定；本字段可选，供显式标注）。
			# JSON 数字恒为 float：先 float 化验收（整），再落 int（见头注口径）
			if p_act.has("phase"):
				var ph: Variant = p_act["phase"]
				if typeof(ph) != TYPE_FLOAT and typeof(ph) != TYPE_INT:
					return "事件 %s 第 %d 个动作 set_story_phase.phase 须为整数" % [p_event_id, p_idx]
				if not is_equal_approx(float(ph), float(int(ph))):
					return "事件 %s 第 %d 个动作 set_story_phase.phase 须为整数" % [p_event_id, p_idx]
			return ""
		"wait", "play_sfx":
			return ""   # E6 钩子占位：无必填字段（验收原文允许空实现占位）
	return "事件 %s 动作类型 %s 未定义校验规则" % [p_event_id, p_type]


## phase 映射校验：键须字符串数字、至少含 "0" 兜底键（GDD §3.2 工程约定原文）、
## 值须非空对话 id 字符串且可解析到真实文件（引用完整性含映射值）。
static func _validate_phase_map(p_map: Dictionary, p_event_id: String, p_idx: int) -> String:
	if p_map.is_empty():
		return "事件 %s 第 %d 个动作 dialogue.id 映射为空（至少含 \"0\" 兜底键）" % [p_event_id, p_idx]
	for k: Variant in p_map.keys():
		var ks := String(k)
		if not ks.is_valid_int():
			return "事件 %s 第 %d 个动作 dialogue.id 映射键 \"%s\" 非数字（键须为 phase 字符串数字）" % [
					p_event_id, p_idx, ks]
		var v: Variant = p_map[k]
		if typeof(v) != TYPE_STRING or (v as String).is_empty():
			return "事件 %s 第 %d 个动作 dialogue.id 映射值须为非空对话 id 字符串" % [p_event_id, p_idx]
	if not p_map.has("0"):
		return "事件 %s 第 %d 个动作 dialogue.id 映射缺 \"0\" 兜底键（GDD §3.2）" % [p_event_id, p_idx]
	for k: Variant in p_map.keys():
		var did := String(p_map[k])
		if not dialogue_exists(did):
			return "事件 %s 第 %d 个动作 dialogue.id 映射引用的对话不存在：\"%s\"" % [
					p_event_id, p_idx, did]
	return ""


# ------------------------------------------------------------------
# phase 映射：规范化与选取（E5-S3 条件评估 / NPC 交互的共同消费口）
# ------------------------------------------------------------------

## 键规范化：{"0": "a", "1": "b"} → {0: "a", 1: "b"}。
## 非数字键返回 {}（validate 已报错；此处防御静默失败不可有——调用方把
## 空结果当失败处置）。
static func normalize_phase_map(p_map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in p_map.keys():
		var ks := String(k)
		if not ks.is_valid_int():
			return {}
		out[ks.to_int()] = String(p_map[k])
	return out


## 选取规则（GDD §3.2 工程约定原文）：取 ≤ 当前 story_phase 的最大键。
## 无匹配键返回空串（正常数据被 "0" 兜底键规则挡住，不可达——防御口）。
## 键同时接受 int（规范化后）与字符串数字（原始 JSON 形态），便于单测直驱。
static func pick_phase_id(p_map: Dictionary, p_phase: int) -> String:
	var best_key: int = -1
	var best_id: String = ""
	for k: Variant in p_map.keys():
		var ki: int = -1
		if typeof(k) == TYPE_STRING:
			if not (k as String).is_valid_int():
				continue   # 非法键跳过（加载校验已拒绝；此处防御）
			ki = (k as String).to_int()
		else:
			ki = int(k)
		if ki > p_phase:
			continue
		if best_key < 0 or ki > best_key:
			best_key = ki
			best_id = String(p_map[k])
	return best_id


## 对话 id 是否可解析（引用完整性原子判定）
static func dialogue_exists(p_id: String) -> bool:
	return FileAccess.file_exists(DIALOGUE_DIR + p_id + ".json")
