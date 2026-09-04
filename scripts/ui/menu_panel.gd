extends Control
## menu_panel.gd —— 主菜单（E6-S1 / EPIC-6 T3.1，UI 规格 §三 v1.1 冻结坐标）
##
## 【职责】C 键呼出 / X·Esc 关闭的五项指令窗（状态/道具/装备/存档/读档）
##   + 状态页三角色块渲染。T3.1 交付菜单壳 + 状态页；T3.2 道具页、
##   T3.3 装备页、T4.1 存读档接线已逐项接入（E6-S4 第 1 步）。
##
## 【引用方式】preload 常量（项目规范，理由同 scripts/core/character_record.gd
##   头注释：headless 跑测通道不重扫全局类注册表，preload 引用即时可用）。
##
## 【边界】（A3）
##   - T3.1 壳阶段只读 GameData / DataTables / SaveManager.has_save()；
##   - T3.2 道具页起【写回】游戏状态：使用道具 → party HP/MP 回复（mini
##     钳制上限，战斗侧 _do_item / BattleLogic.heal_unit 同口径）+
##     inventory 扣减（减一不 erase，与宝箱 give_item / 战斗掉落同字典）；
##   - T4.1 存读档接线：存档 = SaveManager.save_game() 即时落盘（GDD §3.4 +
##     E4-S6 已落地裁决——菜单手动存不依赖 save_requested_pending 门控，
##     那是跨图传送/战后自动存的通道；坐标 = 玩家当前位置）；读档复用
##     DEFEAT 读档路径（load_save → last_loaded → 经 SceneRouter 回存档
##     点，BattleResultHandler map_ready 消费端回置 + 0.5s 免疫）；
##   - 不发业务信号（EventBus 六信号清单零扩容）；
##   - 纯键盘 UI：整棵控件树 mouse_filter = IGNORE（debug_panel 同款）。
##
## 【开合门闸】（try_open 三闸，全部通过才开）
##   1. 对话进行中不开：DialogueRunner.is_idle()（同交互控制器唯一门闸口径；
##      runner 缺席视为空闲——无对话装配的图/测试树直接可开）；
##   2. 战斗中不开：SceneRouter.current_scene_path == BATTLE_SCENE_PATH
##      （战斗场景有自己的 UI，主菜单不得叠现）；
##   3. 转场中不开：SceneRouter._switching（淡入淡出期间场景身份未定）。
##
## 【玩家锁】开菜单 = 玩家 set_input_locked(true)（player.gd A7 同款锁，
##   锁定时 velocity 清零）。菜单 UILayer 常驻而玩家随图生灭 → 不持有玩家
##   引用，每次开合经 "player" 组动态解析（player.tscn 已入组；
##   is_instance_valid 由引擎组查询天然保证——组内不会有已释放节点）。
##
## 【输入路由】_unhandled_input：
##   - 关闭态：只认 menu（C 键；InputMap 缺失时回退直查物理 KEY_C，
##     debug_panel 双保险同款）；其余事件一律放行不消费；
##   - 开启态：模态——move_up/move_down 光标、interact(Z/E) 确认、
##     cancel(X/Esc) 关闭，处理后连同其余按键一律 set_input_as_handled
##     （防漏给交互控制器/NPC 触发器——"菜单开着 Z 不会同时触发 NPC 交互"）。
##     派发顺序依据：UILayer 在 Main 中排 World 之后，_unhandled_input 逆序
##     派发下菜单先于地图子树收到事件，消费即短路。
##
## 【读档项置灰】规格 §3.1："无存档文件时读档置灰"——has_save() 为假时
##   读档条目置灰且光标跳过；每次打开时重算（存档可能在会话中途产生）。
##   存档项恒可用（规格未授权它置灰），确认动作见 _confirm_save_item。
##
## 【布局】全部整数坐标（ADR-4 / 规格 §3.1 冻结值）：
##   指令窗 (16,16,96,136)：5 项 × 行高 24 + 上下内边距 8（5×24+16=136 ✓）
##   状态面板 (128,16,496,328)：三角色块 480×96，块顶绝对 y = 32/136/240
##   块内（块相对坐标）：脸 48×48 (8,24)；名字 12px (64,8)；Lv 8px (64,28)；
##   HP 条 120×6 (200,20) + 8px 数值 (200,8)；MP 条 (200,44) + 数值 (200,32)；
##   ATK/MAG/DEF/SPD 8px 两列 (352,20)/(410,20)/(352,36)/(410,36)。
##   死亡（HP≤0）角色块整块置灰（modulate #8E7F98，规格 §3.1）。
##   【道具子窗（T3.2）】(144,32,232,208)：标题 12px + 列表区 (8,24) 宽 216、
##   8 行 × 行高 24（规格 §3.1"道具列表 8 行滚动"）+ 描述区 8px 两行 (8,216)。
##   子窗覆盖在状态面板区（层级 = 后添加者在上），关闭后状态页原样露出。
##
## 【头像】portrait_catalog.get_texture("<差分>_normal") 取 48×48 脸（零缩放）。
##   注意莉娜的差分注册名是 rina_*（portrait_catalog 占位映射声明）——
##   PORTRAIT_BY_CHAR 显式映射防错。未登记 id 返回 null → 隐藏脸窗
##   （优雅降级，同对话框口径）。
##
## 【窗体】NineSlicePanel（边条 8px 平铺、禁拉伸）注入羊皮纸五色板：
##   外圈/描边 #4A3B52、内底 #E8DCC0、高光 #D9A94E（规格 §3.2 两套窗体框）。
##   注意：NineSlicePanel._rebuild 会清空自身子节点，内容子节点必须在
##   build() 之后加入，且构建后不得再 configure（本类只构建一次）。

# ==============================================================
# 冻结坐标（UI 规格 §3.1，整数）
# ==============================================================
const CMD_RECT := Rect2(16, 16, 96, 136)          # 指令窗
const STATUS_RECT := Rect2(128, 16, 496, 328)     # 状态面板
const BLOCK_SIZE := Vector2(480, 96)              # 角色块
const BLOCK_X := 136.0                            # 面板内缩 8
const BLOCK_YS: Array[float] = [32.0, 136.0, 240.0]  # 块顶绝对 y（规格冻结）
const ROW_H := 24.0                               # 条目行高
const ROW_X_CURSOR := 8.0                         # 光标列 x
const ROW_X_TEXT := 24.0                          # 条目文本列 x
const LIST_TOP := 8.0                             # 列表顶部内边距
const BAR_W := 120.0                              # HP/MP 条宽
const BAR_H := 6.0                                # HP/MP 条高

# ==============================================================
# 五色板（UI 规格 v1.1；Color() 常量表达式，注释为十六进制原值）
# ==============================================================
const C_PARCHMENT := Color(0.909804, 0.862745, 0.752941)  # E8DCC0 内底
const C_INK := Color(0.290196, 0.231373, 0.321569)        # 4A3B52 正文/描边
const C_GOLD := Color(0.850980, 0.662745, 0.305882)       # D9A94E 光标
const C_GRAY := Color(0.556863, 0.498039, 0.596078)       # 8E7F98 置灰
const C_HP_FILL := Color(0.650980, 0.258824, 0.227451)    # A6423A 生命
const C_MP_FILL := Color(0.419608, 0.556863, 0.305882)    # 6B8E4E 法力
const C_BAR_BG := Color(0.145098, 0.115686, 0.160784)     # 4A3B52 压暗条底

# ==============================================================
# 条目与差分映射
# ==============================================================
## 指令条目（槽位序即导航序；id 是公开协议，测试与 T3.2/T3.3/T4 接线对表用）
const ITEM_IDS: Array[String] = ["status", "item", "equip", "save", "load"]
## 条目显示名（规格 §3.1 五项）
const ITEM_LABELS: Dictionary = {
	"status": "状态", "item": "道具", "equip": "装备", "save": "存档", "load": "读档",
}
## 角色 id → 头像差分 id（莉娜注册名是 rina_*，见 portrait_catalog 占位映射）
const PORTRAIT_BY_CHAR: Dictionary = {
	"kyle": "kyle_normal", "lina": "rina_normal", "mona": "mona_normal",
}

## 输入动作名（project.godot [input]；menu=C，cancel=X+Esc，confirm 复用 Z/E）
const ACTION_MENU := "menu"
const ACTION_CANCEL := "cancel"
const ACTION_CONFIRM := "interact"

# ==============================================================
# 道具子窗（T3.2；规格 §3.1 "道具列表 8 行滚动"）
# ==============================================================
## 子窗冻结坐标：覆盖状态面板区左上，8 行滚动列表 + 两行描述区
const ITEM_WINDOW_RECT := Rect2(144, 32, 232, 208)
const ITEM_WINDOW_TITLE := "道具"
const ITEM_LIST_ROWS := 8                  # 可见行数（滚动窗口高）
const ITEM_LIST_POS := Vector2(8, 24)      # 列表区在子窗内的相对位置
const ITEM_LIST_W := 216.0                 # 列表区宽 = 232 - 2×8
const ITEM_DESC_POS := Vector2(8, 216)     # 描述两行区相对位置（8px 字号）
const KIND_TAG: Dictionary = {             # 种类标签（行尾）
	"heal_hp": "HP+", "heal_mp": "MP+", "detox": "解毒",
}

# ==============================================================
# 装备子窗（T3.3；规格 §3.1 "子界面在状态面板区弹出同尺寸窗口"——
# 与道具子窗同 (144,32,232,208)，角色/槽位两态复用同一窗体换标题）
# ==============================================================
const EQUIP_WINDOW_RECT := Rect2(144, 32, 232, 208)
const EQUIP_SLOT_NAMES: Array[String] = ["武器", "防具"]   # 槽位光标序文案

# ==============================================================
# 依赖（preload 常量，项目规范）
# ==============================================================
const NineSlicePanel := preload("res://scripts/battle/nine_slice_panel.gd")
const PortraitCatalog := preload("res://scripts/dialogue/portrait_catalog.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")
const ItemData := preload("res://scripts/data/item_data.gd")
const EquipmentData := preload("res://scripts/data/equipment_data.gd")
const BattleUnits := preload("res://scripts/data/battle_units.gd")
## T4.1 存档接线：地图路径 → 短名反查表（_current_map_name 消费）
const TeleportCatalog := preload("res://scripts/events/teleport_catalog.gd")

# ==============================================================
# 运行时状态
# ==============================================================
## 子模态：主菜单光标态 / 道具两态 / 装备三态（角色→槽位→装备列表）
enum Mode { MAIN, ITEM_LIST, ITEM_TARGET, EQUIP_CHAR, EQUIP_SLOT, EQUIP_LIST }

var _built := false
var _mode: Mode = Mode.MAIN   # 当前子模态（决定 _consume_event 派发走向）
var _cursor_index := 0                 # 主菜单光标槽位（ITEM_IDS 下标）
var _item_cursor := 0                  # 道具列表光标（_item_ids 下标）
var _item_scroll := 0                  # 滚动窗口顶（_item_ids 下标）
var _item_ids: Array[String] = []      # 当前道具页条目（已过滤后背包序）
var _item_target := 0                  # 用药目标槽位（party 下标 0-2）
var _equip_char := 0                   # 装备页：角色槽位光标（party 下标 0-2）
var _equip_slot := 0                   # 装备页：槽位光标（0=武器 1=防具）
var _equip_ids: Array[String] = []     # 装备页：当前槽位可装装备（池过滤后）
var _equip_cursor := 0                 # 装备列表光标（_equip_ids 下标）
var _disabled: Dictionary = {}         # item_id -> bool（打开时重算）
var _cmd_window: Control = null        # 指令窗（NineSlicePanel）
var _status_panel: Control = null      # 状态面板底窗（NineSlicePanel）
var _item_window: Control = null       # 道具子窗（NineSlicePanel，T3.2）
var _cursor_label: Label = null        # ▶ 光标
var _item_labels: Dictionary = {}      # item_id -> Label
var _blocks: Array[Dictionary] = []    # 三角色块控件表（_make_block 产物）
var _iw_rows: Array[Label] = []        # 道具列表可见行标签（8 行复用）
var _iw_count: Label = null            # 选中行右侧 "×N" 数量标签
var _iw_desc: Label = null             # 描述文本标签（两行区）
var _iw_cursor: Label = null           # 道具列表 ▶ 光标
var _eq_window: Control = null         # 装备子窗（NineSlicePanel，T3.3）
var _eq_rows: Array[Label] = []        # 装备列表可见行标签（8 行复用）
var _eq_desc: Label = null             # 装备描述标签
var _eq_cursor: Label = null           # 装备列表 ▶ 光标
var _eq_title: Label = null            # 装备子窗标题（随阶段换文案）


func _ready() -> void:
	# 满铺视口容器（子窗体用绝对坐标落位）；默认关闭（同 debug_panel：不影响首屏）
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(640, 360)
	visible = false
	ensure_built()


## 构建静态控件树（一次性，幂等；可脱离场景树手动调用——GUT 直驱入口）
func ensure_built() -> void:
	if _built:
		return
	_build()
	_built = true


# ==============================================================
# 公开接口（生产装配面 + GUT 直驱面）
# ==============================================================

## 是否打开（visible 即开合态——UI 不持有游戏状态，路径作用域编码标准）
func is_open() -> bool:
	return visible


## 尝试打开（三门闸全过才开；返回 false = 被门闸拒绝，不消费输入语义由
## _unhandled_input 决定）。打开时刷新置灰态与状态页，光标回首个可用项。
func try_open() -> bool:
	if is_open():
		return false
	if not _gates_pass():
		return false
	_refresh_disabled()
	refresh_status_page()
	_mode = Mode.MAIN            # 打开复位到主模态（防上次会话残留子模态）
	_cursor_index = 0
	if is_item_disabled(current_item_id()):
		move_cursor(1)   # 防御分支：首项 status 恒可用，理论不触发
	_update_cursor()
	_apply_input_lock(true)
	visible = true
	print("[MenuPanel] 菜单打开（光标：%s）" % current_item_id())
	return true


## 关闭（幂等；子窗收起 + 解锁玩家）
func close() -> void:
	if not is_open():
		return
	_item_window.visible = false
	_eq_window.visible = false
	_mode = Mode.MAIN
	visible = false
	_apply_input_lock(false)
	print("[MenuPanel] 菜单关闭")


## 当前光标所在条目 id
func current_item_id() -> String:
	return ITEM_IDS[_cursor_index]


## 当前光标槽位下标（测试对表用）
func get_cursor_index() -> int:
	return _cursor_index


## 条目是否置灰（未刷新过时按未置灰兜底）
func is_item_disabled(id: String) -> bool:
	return bool(_disabled.get(id, false))


## 光标移动一步（dir=+1 下 / -1 上），自动跳过置灰项并循环回绕。
## 全部置灰时不动（理论不可达：status/item/equip 恒可用）。返回是否移动。
func move_cursor(dir: int) -> bool:
	var n: int = ITEM_IDS.size()
	var i: int = _cursor_index
	for _step: int in n:
		i = wrapi(i + dir, 0, n)
		if not is_item_disabled(ITEM_IDS[i]):
			_cursor_index = i
			_update_cursor()
			return true
	return false


## 确认当前条目（主模态专用——子模态走 _consume_event 内部分派）。
## 状态=刷新状态页；道具=T3.2 道具页；装备=T3.3 装备页；
## 存档/读档=T4.1 接线（E6-S4 第 1 步，接入点唯一在本函数 match 内）。
func confirm_current() -> void:
	var id := current_item_id()
	match id:
		"status":
			refresh_status_page()
		"item":
			_open_item_list()
		"equip":
			_open_equip_char_select()
		"save":
			_confirm_save_item()
		"load":
			_confirm_load_item()


## 存档项确认（T4.1）：菜单手动存 = 即时落盘，不依赖
## save_requested_pending 门控（那是跨图传送/战后自动存的意图通道，
## AutosaveNotifier 消费口语义不同——手动存绕开门控直接写）。
## 落盘坐标 = 玩家当前位置（"player" 组动态解析，与玩家锁同源口径；
## 测试树/无玩家环境退化为原点——写盘语义仍完整，不因无玩家失败）。
## 地图名取 SceneRouter.current_scene_path（当前探索图正本，与自动存档
## 侧"map 字段=图名"一致；仅探索图可开菜单，故恒有值——战斗中/转场中
## 被 try_open 三门闸拦截，进不到确认动作）。
## 成功后关菜单（存档动作收束，回地图交互）。
func _confirm_save_item() -> void:
	var map_name := _current_map_name()
	var pos := _current_player_position()
	var ok := SaveManager.save(map_name, pos)
	if ok:
		print("[MenuPanel] 存档完成：%s @ %s" % [map_name, pos])
		close()
	else:
		# 写盘失败（磁盘/权限）：旧档保留（SaveManager 原子写语义），
		# 菜单保持打开——玩家可重试或另行操作，不静默假成功。
		push_warning("[MenuPanel] 存档写入失败，旧档保留（菜单保持打开）")


## 读档项确认（T4.1）：复用 DEFEAT 读档路径（E4-S7 已落地链路）——
## SaveManager.load_save()（GameData 整体回滚 + last_loaded 记录快照），
## 再经 EventBus.battle_finished({"outcome":"DEFEAT"}) 走既有回图链：
## BattleResultHandler 取 last_loaded 的 map/position 经 SceneRouter 回
## 存档点，map_ready 后回置玩家 + 启动 0.5s 遇敌免疫（口径如既有实现，
## 存档点常在敌人接触范围内时不秒进战斗）。battle_finished 的另一消费端
## battle_event_bridge 在无事件流簿记时直通返回——菜单场景簿记恒空，
## 不会误触事件流续行。
## 前置：读档项置灰闸（has_save()=false 时条目置灰且光标跳过）保证
## 本分支只在有档时可达；防御式再查一次，无档直接静默返回（防御置灰
## 态与文件态之间的窗口——如运行中被外部删档）。
func _confirm_load_item() -> void:
	if not SaveManager.has_save():
		print("[MenuPanel] 读档：无存档文件，忽略（置灰态防御兜底）")
		return
	if not SaveManager.load_save():
		# 档在但损坏/格式未来版本：GameData 未动（SaveManager 语义），
		# 菜单保持打开，玩家可取消退出。告警交诊断。
		push_warning("[MenuPanel] 读档失败（存档损坏或版本不受支持），菜单保持打开")
		return
	print("[MenuPanel] 读档成功 -> %s @ %s，关闭菜单回图" % [
			String(SaveManager.last_loaded["map"]),
			SaveManager.last_loaded["position"]])
	close()
	# 事件通道回图（A5 唯一通路；常驻消费端 BattleResultHandler 接手回置）
	EventBus.battle_finished.emit({"outcome": "DEFEAT", "party_state": []})


## 当前地图名（SceneRouter 簿记直读——A3：路由簿记非游戏状态，菜单
## 只读不写）。仅探索图可开菜单（三门闸拦截战斗/转场），故恒非空；
## 异常空值兜底 "town"（首个探索图，防存档 map 字段为空串不可回图）。
func _current_map_name() -> String:
	var path := SceneRouter.current_scene_path
	if path.is_empty():
		return "town"
	# 路径 → 短名反查（TeleportCatalog.MAP_SCENE_PATHS 的镜像；
	# 未登记路径（理论上不可达）按文件名去扩展名兜底）
	for map_name: String in TeleportCatalog.MAP_SCENE_PATHS:
		if String(TeleportCatalog.MAP_SCENE_PATHS[map_name]) == path:
			return map_name
	return path.get_file().get_basename()


## 玩家当前位置（"player" 组动态解析——菜单常驻 UILayer 不持有玩家
## 引用，与 _apply_input_lock 同源口径）。无玩家/未入树退化为原点。
func _current_player_position() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var p: Node = get_tree().get_first_node_in_group("player")
	if p is Node2D:
		return (p as Node2D).global_position
	return Vector2.ZERO


## 重刷状态页（GameData.party 直读；打开时与 status 确认时各刷一次）
func refresh_status_page() -> void:
	for i: int in 3:
		var b: Dictionary = _blocks[i]
		var root: Control = b["root"]
		if i >= GameData.party.size():
			root.visible = false
			continue
		var rec: Resource = GameData.party[i]
		root.visible = true
		# 名字 / 等级（记录直读）
		(b["name"] as Label).text = String(rec.name)
		(b["lv"] as Label).text = "Lv%d" % rec.level
		# HP/MP 条与数值（记录的当前值/上限值——运行时正本）
		var hp_ratio := 0.0
		if rec.max_hp > 0:
			hp_ratio = clampf(float(rec.hp) / float(rec.max_hp), 0.0, 1.0)
		var mp_ratio := 0.0
		if rec.max_mp > 0:
			mp_ratio = clampf(float(rec.mp) / float(rec.max_mp), 0.0, 1.0)
		(b["hp_fill"] as ColorRect).size = Vector2(BAR_W * hp_ratio, BAR_H)
		(b["mp_fill"] as ColorRect).size = Vector2(BAR_W * mp_ratio, BAR_H)
		(b["hp_val"] as Label).text = "%d/%d" % [rec.hp, rec.max_hp]
		(b["mp_val"] as Label).text = "%d/%d" % [rec.mp, rec.max_mp]
		# ATK/MAG/DEF/SPD 面板值（数值表 stats_at 派生——E3-S2 口径③：
		# 派生函数直接用，不在 UI 里重算 base + per_level × (level-1)）。
		# T3.3 装备并项：走 BattleUnits.apply_equipment 同源叠加——
		# 面板数字 = 战斗公式输入，两处永不漂移（验收第 3 条口径）。
		var stats: Dictionary = {}
		var cd: Resource = DataTables.get_character(rec.id)
		if cd != null:
			stats = cd.stats_at(rec.level)
			stats = BattleUnits.apply_equipment(stats,
					String(rec.weapon_id), String(rec.armor_id))
		(b["atk"] as Label).text = "ATK%d" % int(stats.get("atk", 0))
		(b["mag"] as Label).text = "MAG%d" % int(stats.get("mag", 0))
		(b["def"] as Label).text = "DEF%d" % int(stats.get("def", 0))
		(b["spd"] as Label).text = "SPD%d" % int(stats.get("spd", 0))
		# 头像 48×48（零缩放）；未登记 → 隐藏（优雅降级，同对话框口径）
		var face: TextureRect = b["face"]
		var tex: Texture2D = PortraitCatalog.get_texture(
				String(PORTRAIT_BY_CHAR.get(rec.id, "")))
		face.texture = tex
		face.visible = tex != null
		# 死亡（HP≤0）整块置灰（规格 §3.1：modulate 预混 #8E7F98 口径）
		root.modulate = C_GRAY if rec.hp <= 0 else Color.WHITE


# ==============================================================
# 道具页（T3.2）——过滤/导航/目标选择/使用写回
# ==============================================================

## 道具页是否处于子模态（列表或目标选择；测试与 T4 存档接线对表用）
func is_item_page_open() -> bool:
	return _mode != Mode.MAIN


## 当前子模态名（测试断言用："main"/"item_list"/"item_target"/
## "equip_char"/"equip_slot"/"equip_list"——六态全量映射，缺一支
## 就会在查询口漏报回 "main"（T3.3 首轮 6 断言假挂的教训））
func get_mode() -> String:
	match _mode:
		Mode.ITEM_LIST:
			return "item_list"
		Mode.ITEM_TARGET:
			return "item_target"
		Mode.EQUIP_CHAR:
			return "equip_char"
		Mode.EQUIP_SLOT:
			return "equip_slot"
		Mode.EQUIP_LIST:
			return "equip_list"
	return "main"


## 当前道具页光标所指的道具 id（列表态/目标态通用；空列表返回 ""）
func get_current_item_id() -> String:
	if _item_ids.is_empty():
		return ""
	return _item_ids[_item_cursor]


## 道具页条目表（id→数量字典快照；测试对表用，外部只读）
func get_item_page_entries() -> Dictionary:
	var out: Dictionary = {}
	for iid: String in _item_ids:
		out[iid] = int(GameData.inventory.get(iid, 0))
	return out


## 打开道具列表：读背包 → usable_in_map() 过滤 → 渲染。
## 过滤口径 = EPIC-6 E6-S1 验收第 2 条"道具使用遵守可用阶段字段"；
## 行序 = GameData.inventory 键序（插入序，与掉落/宝箱入包序一致）。
func _open_item_list() -> void:
	_item_ids = []
	for iid: Variant in GameData.inventory:
		var count := int(GameData.inventory.get(iid, 0))
		if count <= 0:
			continue
		var item: ItemData = DataTables.get_item(String(iid))
		if item != null and item.usable_in_map():
			_item_ids.append(String(iid))
	_item_cursor = 0
	_item_scroll = 0
	_item_window.visible = true
	_mode = Mode.ITEM_LIST
	_refresh_item_rows()
	if _item_ids.is_empty():
		print("[MenuPanel] 道具页打开（背包无地图可用道具）")
	else:
		print("[MenuPanel] 道具页打开（%d 种）" % _item_ids.size())


## 关道具列表回主模态（收子窗；状态页原样露出——状态页始终在刷）
func _close_item_list() -> void:
	_item_window.visible = false
	_mode = Mode.MAIN
	print("[MenuPanel] 道具页关闭")


## 列表光标移动（+1/-1，回绕；同步滚动窗口与行渲染）
func _item_move(dir: int) -> void:
	var n := _item_ids.size()
	if n == 0:
		return
	_item_cursor = wrapi(_item_cursor + dir, 0, n)
	# 滚动窗口跟随：光标出窗即挪窗（每次一步，与像素风滚动手感一致）
	if _item_cursor < _item_scroll:
		_item_scroll = _item_cursor
	elif _item_cursor >= _item_scroll + ITEM_LIST_ROWS:
		_item_scroll = _item_cursor - ITEM_LIST_ROWS + 1
	_refresh_item_rows()


## 列表确认：有道具才进目标选择（空列表 Z 是静默 no-op——无死层也无可选）
func _item_confirm() -> void:
	if _item_ids.is_empty():
		return
	# 目标默认回第一个存活成员（每次进入重置，不记忆上次目标）
	_item_target = 0
	_mode = Mode.ITEM_TARGET
	_highlight_target(true)


## 目标光标移动（回绕；用死亡块置灰视觉标记当前目标——目标态下
## 高亮即"目标指环"，叠加在块置灰之上，规格无冻结坐标故用 modulate 乘法）
func _target_move(dir: int) -> void:
	_item_target = wrapi(_item_target + dir, 0, 3)
	_highlight_target(true)


## 目标态取消：回列表态（子窗已在目标态保持可见，只换模式与高亮）
func _back_to_item_list() -> void:
	_highlight_target(false)
	_mode = Mode.ITEM_LIST


## 使用当前道具于当前目标，写回游戏状态（T3.2 唯一写盘点）。
## 写回口径与战斗侧 _do_item / BattleLogic.heal_unit 一致：
##   heal_hp → hp = mini(max_hp, hp + value)
##   heal_mp → mp = mini(max_mp, mp + value)
##   detox   → 地图态无数值变化（CharacterRecord 无中毒字段，中毒是
##             战斗侧 unit 字典状态；地图态不设中毒，真实清毒在战斗侧）
## 库存扣减统一"减一不 erase"（与宝箱/掉落同字典；0 值条目被
## _open_item_list 过滤口径天然隐藏）。死后库存归零仍不关页——
## 可继续选中下一件或 X 回主菜单。
## 返回 true = 用药生效（库存扣减完成）。
func _apply_item() -> bool:
	if _item_ids.is_empty():
		return false
	var iid := _item_ids[_item_cursor]
	var count := int(GameData.inventory.get(iid, 0))
	if count <= 0:
		return false   # 防御：无库存不得消耗（正常路径进不来）
	var item: ItemData = DataTables.get_item(iid)
	if item == null:
		return false
	if _item_target >= GameData.party.size():
		return false   # 防御：目标槽越界（party 缩员场景）
	var rec: Resource = GameData.party[_item_target]
	match item.kind:
		ItemData.KIND_HEAL_HP:
			rec.hp = mini(rec.max_hp, rec.hp + item.value)
		ItemData.KIND_HEAL_MP:
			rec.mp = mini(rec.max_mp, rec.mp + item.value)
		ItemData.KIND_DETOX:
			pass   # 地图态无状态可清（裁决见函数头注释）
	GameData.inventory[iid] = count - 1
	refresh_status_page()   # 数值/条宽即时回显（含死亡块置灰解除）
	_highlight_target(false)
	print("[MenuPanel] 使用 %s → %s（剩 %d）" % [item.name, rec.name, count - 1])
	# 用药后留在目标态（连续喂药手感）；列表态与目标态共用子窗
	return true


## 目标高亮：目标态下用置灰色的"反相"表达——非目标块压暗、目标块正常。
## 挖空块的选取顺序 = party 槽位序（0/1/2），与状态页三块一一对应。
func _highlight_target(active: bool) -> void:
	for i: int in 3:
		var b: Dictionary = _blocks[i]
		if i >= GameData.party.size():
			continue
		var root: Control = b["root"]
		if not active:
			# 还原：交回 refresh_status_page 的置灰口径（死亡灰/正常白）
			root.modulate = C_GRAY if GameData.party[i].hp <= 0 else Color.WHITE
		else:
			root.modulate = Color.WHITE if i == _item_target else Color(0.72, 0.68, 0.74)


## 道具列表行渲染：可见窗 8 行复用 8 个 Label，滚动窗口外的行隐藏。
## 行文本 = "名称 ×N"，行尾种类标签列对齐（KIND_TAG）；描述区随光标刷新。
func _refresh_item_rows() -> void:
	for row: int in ITEM_LIST_ROWS:
		var idx := _item_scroll + row
		var lbl := _iw_rows[row]
		if idx >= _item_ids.size():
			lbl.visible = false
			continue
		lbl.visible = true
		var iid := _item_ids[idx]
		var item: ItemData = DataTables.get_item(iid)
		var disp := item.name if item != null else iid
		var count := int(GameData.inventory.get(iid, 0))
		var tag := String(KIND_TAG.get(item.kind, "")) if item != null else ""
		lbl.text = "%s ×%d  %s" % [disp, count, tag]
	_iw_cursor.visible = not _item_ids.is_empty()
	_iw_cursor.position = Vector2(ITEM_LIST_POS.x - 12.0,
			ITEM_LIST_POS.y + float(_item_cursor - _item_scroll) * ROW_H + 4.0)
	var cur: ItemData = null
	if not _item_ids.is_empty():
		cur = DataTables.get_item(_item_ids[_item_cursor])
	_iw_desc.text = cur.description if cur != null else "（背包里没有可用的道具）"


## 构建道具子窗（NineSlicePanel；在 _build 尾部调用——内容节点
## 必须在 build() 之后加入，NineSlicePanel._rebuild 清空子节点陷阱）。
func _build_item_window() -> void:
	_item_window = _parchment_panel("ItemWindow",
			ITEM_WINDOW_RECT.position, ITEM_WINDOW_RECT.size)
	_item_window.visible = false
	# 标题行（12px，墨色）
	var title := _make_label("Title", Vector2(8, 4), 12)
	title.text = ITEM_WINDOW_TITLE
	_item_window.add_child(title)
	# 列表 8 行（滚动复用）+ 光标
	for row: int in ITEM_LIST_ROWS:
		var lbl := _make_label("Row%d" % row,
				ITEM_LIST_POS + Vector2(0, float(row) * ROW_H), 12)
		_item_window.add_child(lbl)
		_iw_rows.append(lbl)
	_iw_cursor = Label.new()
	_iw_cursor.name = "ItemCursor"
	_iw_cursor.text = "▶"
	_iw_cursor.add_theme_font_size_override("font_size", 12)
	_iw_cursor.add_theme_color_override("font_color", C_GOLD)
	_iw_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_window.add_child(_iw_cursor)
	# 描述区（8px 两行；autowrap 软换行）
	_iw_desc = _make_label("Desc", ITEM_DESC_POS, 8)
	_iw_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_iw_desc.custom_minimum_size = Vector2(ITEM_LIST_W, 0.0)
	_iw_desc.size = Vector2(ITEM_LIST_W, 24.0)
	_item_window.add_child(_iw_desc)


# ==============================================================
# 装备页（T3.3）——角色→槽位→列表三态 + 换装写回
# ==============================================================

## 打开装备页·角色选择态：高亮状态页角色块当光标（复用块置灰视觉，
## 与道具页目标态同手法），子窗不弹（无列表可渲染）
func _open_equip_char_select() -> void:
	_equip_char = 0
	_eq_title.text = "给谁换装？"
	_eq_window.visible = true
	_refresh_equip_rows_hide()
	_mode = Mode.EQUIP_CHAR
	_highlight_equip_char(true)


## 角色块高亮（装备·角色态光标）：当前角色块正常、其余压暗。
## 不叠死亡置灰判定——装备态下高亮语义优先（死亡者也可换装，
## 复活后加成自然生效；状态页刷新会把死亡块重新置灰）。
func _highlight_equip_char(active: bool) -> void:
	for i: int in 3:
		if i >= GameData.party.size():
			continue
		var root: Control = _blocks[i]["root"]
		if not active:
			root.modulate = C_GRAY if GameData.party[i].hp <= 0 else Color.WHITE
		else:
			root.modulate = Color.WHITE if i == _equip_char else Color(0.72, 0.68, 0.74)


## 打开装备列表态：持有池按槽位过滤 -> 渲染（含"卸下"伪条目置底）。
## weapon 槽过滤 slot=="weapon"，armor 同理；"卸下"始终可选（换空手/
## 空身语义，写回空串）。列表条目序=池插入序+卸下置底。
func _open_equip_list() -> void:
	var want := "weapon" if _equip_slot == 0 else "armor"
	_equip_ids = []
	for eid: String in GameData.owned_equipment:
		var eq: EquipmentData = DataTables.get_equipment(eid)
		if eq != null and eq.slot == want:
			_equip_ids.append(eid)
	_equip_cursor = 0
	_mode = Mode.EQUIP_LIST
	_refresh_equip_rows()


## 列表态收起（回角色选择态的视觉复位：行隐藏、标题回问句）
func _refresh_equip_rows_hide() -> void:
	for row: int in ITEM_LIST_ROWS:
		_eq_rows[row].visible = false
	_eq_cursor.visible = false
	_eq_desc.text = "↑↓ 选角色，Z 确认。"


## 装备列表渲染：可见行 = 过滤后装备 + 置底"卸下"（当前已装则不带卸下行——
## 卸下与再装同件装备是等价操作，去重防重复条目）。
## 行文本 = "名称 ATK+3" / "名称 DEF+2"；描述区随光标刷新。
func _refresh_equip_rows() -> void:
	var rec: Resource = GameData.party[_equip_char]
	var cur_id := String(rec.weapon_id) if _equip_slot == 0 else String(rec.armor_id)
	var has_unequip := not cur_id.is_empty()
	for row: int in ITEM_LIST_ROWS:
		var lbl := _eq_rows[row]
		# 条目映射：row < _equip_ids.size() 为装备行；最后一行（若可用）为卸下
		if has_unequip and row == _equip_ids.size():
			lbl.visible = true
			lbl.text = "（卸下）"
			continue
		if row >= _equip_ids.size():
			lbl.visible = false
			continue
		lbl.visible = true
		var eq: EquipmentData = DataTables.get_equipment(_equip_ids[row])
		if eq == null:
			lbl.text = _equip_ids[row]
			continue
		if eq.atk_bonus > 0:
			lbl.text = "%s ATK+%d" % [eq.name, eq.atk_bonus]
		else:
			lbl.text = "%s DEF+%d" % [eq.name, eq.def_bonus]
	var total := _equip_ids.size() + (1 if has_unequip else 0)
	_eq_cursor.visible = total > 0
	_eq_cursor.position = Vector2(ITEM_LIST_POS.x - 12.0,
			ITEM_LIST_POS.y + float(_equip_cursor) * ROW_H + 4.0)
	# 描述区：装备行读 description；卸下行给操作提示
	if has_unequip and _equip_cursor == _equip_ids.size():
		_eq_desc.text = "卸下当前%s。" % EQUIP_SLOT_NAMES[_equip_slot]
	elif _equip_ids.is_empty() and not has_unequip:
		_eq_desc.text = "背包里没有可装备的%s。" % EQUIP_SLOT_NAMES[_equip_slot]
	else:
		var eq: EquipmentData = DataTables.get_equipment(_equip_ids[_equip_cursor])
		_eq_desc.text = eq.description if eq != null else ""


## 换装写回（T3.3 唯一写盘点）：三向库存搬移——
##   旧装（若有）→ 回持有池；新装（选中装备行）→ 池移除、写角色字段；
##   卸下行 → 只回旧装、角色字段清空。
## 写回后刷新状态页（ATK/DEF 即时反映——验收第 3 条"面板反映"半边；
## 战斗侧半边由 build_party_unit(equip) 同源叠加）。
## 返回 true = 换装生效。
func _apply_equipment_change() -> bool:
	var rec: Resource = GameData.party[_equip_char]
	var slot_field := "weapon_id" if _equip_slot == 0 else "armor_id"
	var cur_id := String(rec.get(slot_field))
	# 光标行语义：== _equip_ids.size() 为卸下；否则为装备行
	var pick_unequip := _equip_cursor >= _equip_ids.size()
	var new_id := "" if pick_unequip else _equip_ids[_equip_cursor]
	if new_id == cur_id:
		return false   # 同件重复确认：无变化（防御，正常路径少触发）
	# 旧装回池（池是 Array[String]，防重复插入——理论不会发生，防御式）
	if not cur_id.is_empty() and not GameData.owned_equipment.has(cur_id):
		GameData.owned_equipment.append(cur_id)
	# 新装出池 + 写角色字段
	if not new_id.is_empty():
		GameData.owned_equipment.erase(new_id)
		rec.set(slot_field, new_id)
	else:
		rec.set(slot_field, "")
	refresh_status_page()   # ATK/DEF 面板即时回显
	print("[MenuPanel] %s 换装 %s：[%s]" % [
			rec.name, EQUIP_SLOT_NAMES[_equip_slot],
			new_id if not new_id.is_empty() else "卸下"])
	return true


## 构建装备子窗（与道具子窗同构；_build 尾部在道具子窗之后调用，
## 两者互斥可见——同尺寸同位置，谁后 visible=true 谁在上）
func _build_equip_window() -> void:
	_eq_window = _parchment_panel("EquipWindow",
			EQUIP_WINDOW_RECT.position, EQUIP_WINDOW_RECT.size)
	_eq_window.visible = false
	_eq_title = _make_label("EqTitle", Vector2(8, 4), 12)
	_eq_title.text = "给谁换装？"
	_eq_window.add_child(_eq_title)
	for row: int in ITEM_LIST_ROWS:
		var lbl := _make_label("EqRow%d" % row,
				ITEM_LIST_POS + Vector2(0, float(row) * ROW_H), 12)
		_eq_window.add_child(lbl)
		_eq_rows.append(lbl)
	_eq_cursor = Label.new()
	_eq_cursor.name = "EquipCursor"
	_eq_cursor.text = "▶"
	_eq_cursor.add_theme_font_size_override("font_size", 12)
	_eq_cursor.add_theme_color_override("font_color", C_GOLD)
	_eq_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eq_window.add_child(_eq_cursor)
	_eq_desc = _make_label("EqDesc", ITEM_DESC_POS, 8)
	_eq_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_eq_desc.custom_minimum_size = Vector2(ITEM_LIST_W, 0.0)
	_eq_desc.size = Vector2(ITEM_LIST_W, 24.0)
	_eq_window.add_child(_eq_desc)


# ==============================================================
# 测试对表读取口（避免测试侧动态 call；Coordinate 对表 = E6-S1 验收点）
# ==============================================================

func get_cmd_window() -> Control:
	return _cmd_window


func get_status_panel() -> Control:
	return _status_panel


## 道具子窗（T3.2 冻结坐标对表用；未构建时 null）
func get_item_window() -> Control:
	return _item_window


## 装备子窗（T3.3 冻结坐标对表用；未构建时 null）
func get_equip_window() -> Control:
	return _eq_window


## 第 slot 块（0-2）控件表；未构建时返回空字典
func get_block(slot: int) -> Dictionary:
	if slot < 0 or slot >= _blocks.size():
		return {}
	return _blocks[slot]


## C 键判定（含 InputMap 缺失时的物理 KEY_C 回退，debug_panel 双保险同款）。
## 仅认"刚按下"（pressed 且非 echo）；Ctrl 按住放行（预留组合键空间）。
func _is_menu_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			return false
		if InputMap.has_action(ACTION_MENU) and event.is_action_pressed(ACTION_MENU):
			return true
		# 回退通道：工程未注册 menu 动作时按物理 C 键直判
		if (event as InputEventKey).physical_keycode == KEY_C:
			return true
	return false


# ==============================================================
# 输入路由（模态语义见头注释【输入路由】）
# ==============================================================
func _unhandled_input(event: InputEvent) -> void:
	if _consume_event(event):
		get_viewport().set_input_as_handled()


## 输入消费判定（公开供测试直驱，免穿透视口派发管线；返回 true = 菜单
## 消费该事件——生产侧 _unhandled_input 据此阻断后续派发）。
## 开启态吞一切键（模态）：识别键按语义处理，其余键也返回 true。
## 子模态（道具列表/目标选择）同模态——C 键在子模态中只吞不动作。
func _consume_event(event: InputEvent) -> bool:
	# C 键：关闭态开菜单；开启态吞掉但不动作（关闭统一走 X/Esc，
	# 防玩家在道具列表深处按 C 一路弹穿回地图——语义单向）
	if _is_menu_key(event):
		if not is_open():
			try_open()
		return true
	if not is_open():
		return false
	match _mode:
		Mode.MAIN:
			_consume_main(event)
		Mode.ITEM_LIST:
			_consume_item_list(event)
		Mode.ITEM_TARGET:
			_consume_item_target(event)
		Mode.EQUIP_CHAR:
			_consume_equip_char(event)
		Mode.EQUIP_SLOT:
			_consume_equip_slot(event)
		Mode.EQUIP_LIST:
			_consume_equip_list(event)
	return true


## 主模态按键（↑↓ 光标 / Z 确认 / X·Esc 关窗）
func _consume_main(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		move_cursor(-1)
	elif event.is_action_pressed("move_down"):
		move_cursor(1)
	elif event.is_action_pressed(ACTION_CONFIRM):
		confirm_current()
	elif event.is_action_pressed(ACTION_CANCEL):
		close()


## 道具列表模态按键（↑↓ 移动 / Z 进目标选择 / X·Esc 回主模态）
func _consume_item_list(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_item_move(-1)
	elif event.is_action_pressed("move_down"):
		_item_move(1)
	elif event.is_action_pressed(ACTION_CONFIRM):
		_item_confirm()
	elif event.is_action_pressed(ACTION_CANCEL):
		_close_item_list()


## 目标选择模态按键（↑↓ 换目标 / Z 用药 / X·Esc 回列表）
func _consume_item_target(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_target_move(-1)
	elif event.is_action_pressed("move_down"):
		_target_move(1)
	elif event.is_action_pressed(ACTION_CONFIRM):
		_apply_item()
	elif event.is_action_pressed(ACTION_CANCEL):
		_back_to_item_list()


## 装备·角色选择态按键（↑↓ 换角色 / Z 进槽位选择 / X·Esc 回主模态）
func _consume_equip_char(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_equip_char = wrapi(_equip_char - 1, 0, 3)
		_highlight_equip_char(true)
	elif event.is_action_pressed("move_down"):
		_equip_char = wrapi(_equip_char + 1, 0, 3)
		_highlight_equip_char(true)
	elif event.is_action_pressed(ACTION_CONFIRM):
		_equip_slot = 0   # 每次进入重置为武器槽（与道具页目标重置同口径）
		_mode = Mode.EQUIP_SLOT
		_eq_title.text = "%s·装备哪一栏？" % GameData.party[_equip_char].name
		_highlight_equip_char(true)
	elif event.is_action_pressed(ACTION_CANCEL):
		_highlight_equip_char(false)
		_eq_window.visible = false
		_mode = Mode.MAIN


## 装备·槽位选择态按键（↑↓ 换槽 / Z 进装备列表 / X·Esc 回角色选择）
func _consume_equip_slot(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_equip_slot = wrapi(_equip_slot - 1, 0, 2)
		_eq_title.text = "%s·装备哪一栏？（%s）" % [
				GameData.party[_equip_char].name, EQUIP_SLOT_NAMES[_equip_slot]]
	elif event.is_action_pressed("move_down"):
		_equip_slot = wrapi(_equip_slot + 1, 0, 2)
		_eq_title.text = "%s·装备哪一栏？（%s）" % [
				GameData.party[_equip_char].name, EQUIP_SLOT_NAMES[_equip_slot]]
	elif event.is_action_pressed(ACTION_CONFIRM):
		_open_equip_list()
	elif event.is_action_pressed(ACTION_CANCEL):
		_eq_title.text = "给谁换装？"
		_mode = Mode.EQUIP_CHAR


## 装备·列表态按键（↑↓ 移动 / Z 换装 / X·Esc 回槽位选择）
func _consume_equip_list(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_equip_cursor = wrapi(_equip_cursor - 1, 0, _equip_ids.size())
		_refresh_equip_rows()
	elif event.is_action_pressed("move_down"):
		_equip_cursor = wrapi(_equip_cursor + 1, 0, _equip_ids.size())
		_refresh_equip_rows()
	elif event.is_action_pressed(ACTION_CONFIRM):
		_apply_equipment_change()
	elif event.is_action_pressed(ACTION_CANCEL):
		_refresh_equip_rows_hide()
		_eq_title.text = "给谁换装？"
		_mode = Mode.EQUIP_CHAR


# ==============================================================
# 门闸与玩家锁
# ==============================================================

## 置灰态重算（每次打开时调用——存档可能在会话中途产生）。
## 规格授权的置灰项只有读档（has_save()=false）；其余条目恒可用。
func _refresh_disabled() -> void:
	_disabled = {"load": not SaveManager.has_save()}


## 三门闸（见头注释【开合门闸】）。SceneRouter 簿记在测试树中可直接复位，
## 与既有 GUT 隔离纪律（_staged_payload/current_scene_path/_switching）同源。
func _gates_pass() -> bool:
	if SceneRouter._switching:
		return false
	if SceneRouter.current_scene_path == SceneRouter.BATTLE_SCENE_PATH:
		return false
	# runner 缺席视为空闲（同交互控制器 null-runner 口径：无对话装配的图不拦）
	var runner: Node = null
	if get_parent() != null:
		runner = get_parent().get_node_or_null("DialogueRunner")
	if runner != null and runner.has_method("is_idle") and not runner.is_idle():
		return false
	return true


## 玩家锁开关：经 "player" 组动态解析（菜单常驻 UILayer，玩家随图生灭，
## 不持有引用——组内查询天然不含已释放节点）。无玩家（纯 UI 测试树）时跳过。
func _apply_input_lock(locked: bool) -> void:
	if not is_inside_tree():
		return
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("set_input_locked"):
		p.set_input_locked(locked)


# ==============================================================
# 构建
# ==============================================================

func _build() -> void:
	# 指令窗：五条目 + 光标
	_cmd_window = _parchment_panel("CmdWindow", CMD_RECT.position, CMD_RECT.size)
	for i: int in ITEM_IDS.size():
		var id: String = ITEM_IDS[i]
		var lbl := Label.new()
		lbl.name = "Item_" + id
		lbl.text = ITEM_LABELS[id]
		lbl.position = Vector2(ROW_X_TEXT, _row_y(i) + 4.0)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_INK)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cmd_window.add_child(lbl)
		_item_labels[id] = lbl
	_cursor_label = Label.new()
	_cursor_label.name = "Cursor"
	_cursor_label.text = "▶"
	_cursor_label.add_theme_font_size_override("font_size", 12)
	_cursor_label.add_theme_color_override("font_color", C_GOLD)
	_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cmd_window.add_child(_cursor_label)

	# 状态面板底窗 + 三角色块（块挂根节点绝对定位，规格冻结坐标直落）
	_status_panel = _parchment_panel("StatusPanel", STATUS_RECT.position, STATUS_RECT.size)
	for i: int in 3:
		_blocks.append(_make_block(i))
	_update_cursor()
	# 道具子窗（T3.2；必须在状态面板之后创建保证层级在上）
	_build_item_window()
	# 装备子窗（T3.3；同尺寸同位置与道具子窗互斥可见，后创建者在最上）
	_build_equip_window()


## 第 i 条目行的 y（列表顶内边距 + 行高步进）
func _row_y(i: int) -> float:
	return LIST_TOP + float(i) * ROW_H


## 光标位置与条目置灰态刷新（置灰 = 文字 #8E7F98，规格 §0.2 预混口径）
func _update_cursor() -> void:
	for i: int in ITEM_IDS.size():
		var id: String = ITEM_IDS[i]
		var lbl: Label = _item_labels[id]
		lbl.add_theme_color_override("font_color",
				C_GRAY if is_item_disabled(id) else C_INK)
	_cursor_label.position = Vector2(ROW_X_CURSOR, _row_y(_cursor_index) + 4.0)


## 羊皮纸五色板窗体（NineSlicePanel 注入；见类注释【窗体】的清空注意）
func _parchment_panel(p_name: String, pos: Vector2, p_size: Vector2) -> Control:
	var p := NineSlicePanel.new()
	p.name = p_name
	p.position = pos
	p.size = p_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 外圈/描边 #4A3B52、内底 #E8DCC0、高光 #D9A94E（规格 §3.2）
	p.configure(C_INK, C_PARCHMENT, C_INK, C_INK, C_GOLD)
	p.build()
	add_child(p)
	return p


## 第 i 块角色控件表（块内相对坐标全部按规格 §3.1 冻结值）
func _make_block(i: int) -> Dictionary:
	var root: Control = _parchment_panel("Block%d" % i,
			Vector2(BLOCK_X, BLOCK_YS[i]), BLOCK_SIZE)
	# 48×48 脸（零缩放；纹理在 refresh_status_page 注入）
	var face := TextureRect.new()
	face.name = "Face"
	face.position = Vector2(8, 24)
	face.size = Vector2(48, 48)
	face.stretch_mode = TextureRect.STRETCH_KEEP
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(face)
	# 名字 12px (64,8) / Lv 8px (64,28)
	var name_lbl := _make_label("Name", Vector2(64, 8), 12)
	root.add_child(name_lbl)
	root.add_child(_make_label("Lv", Vector2(64, 28), 8))
	# HP 条 (200,20) + 数值 (200,8)；MP 条 (200,44) + 数值 (200,32)
	var hp_bg := _make_bar("HpBg", Vector2(200, 20), C_BAR_BG)
	root.add_child(hp_bg)
	var hp_fill := _make_bar("HpFill", Vector2(200, 20), C_HP_FILL)
	root.add_child(hp_fill)
	root.add_child(_make_label("HpVal", Vector2(200, 8), 8))
	var mp_bg := _make_bar("MpBg", Vector2(200, 44), C_BAR_BG)
	root.add_child(mp_bg)
	var mp_fill := _make_bar("MpFill", Vector2(200, 44), C_MP_FILL)
	root.add_child(mp_fill)
	root.add_child(_make_label("MpVal", Vector2(200, 32), 8))
	# ATK/MAG/DEF/SPD 两列 (352,20)/(410,20)/(352,36)/(410,36)
	root.add_child(_make_label("Atk", Vector2(352, 20), 8))
	root.add_child(_make_label("Mag", Vector2(410, 20), 8))
	root.add_child(_make_label("Def", Vector2(352, 36), 8))
	root.add_child(_make_label("Spd", Vector2(410, 36), 8))
	return {
		"root": root, "face": face, "name": name_lbl,
		"lv": root.get_node("Lv"), "hp_fill": hp_fill, "mp_fill": mp_fill,
		"hp_val": root.get_node("HpVal"), "mp_val": root.get_node("MpVal"),
		"atk": root.get_node("Atk"), "mag": root.get_node("Mag"),
		"def": root.get_node("Def"), "spd": root.get_node("Spd"),
	}


## 文本标签（默认墨色；置灰/数值色由调用处覆盖）
func _make_label(p_name: String, pos: Vector2, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.name = p_name
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", C_INK)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## 纯色条底/填充（1×1 语义的纯色矩形，Nearest 下无变形问题——规格 §1.3 同款）
func _make_bar(p_name: String, pos: Vector2, color: Color) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = p_name
	bar.position = pos
	bar.size = Vector2(BAR_W, BAR_H)
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
