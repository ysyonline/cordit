extends Control

## 战斗 HUD（E3-S4 · GDD §4 八要素，战斗背景归 S5）
##
## 【定位】纯视图层。只读 BattleCommand 模型并渲染；不持有战斗逻辑、
##   不写存档（A1 铁律 3 / A2）。玩家操作经 command_selected / target_chosen
##   信号回传，由上层（battle_scene / 控制器）驱动 cmd.submit_command。
##
## 【布局】ADR-4 口径：640×360、整数像素；所有面板用 NineSlicePanel
##   （边条 8px 平铺、禁拉伸）。浮动数字五色按 §4.6。

# ==============================================================
# 信号
# ==============================================================
signal command_selected(command: Dictionary)   # 玩家在菜单/目标确认后提交完整指令
signal target_chosen(target_slot: int)         # 目标光标确认（备用；command_selected 已含 target_slot）
signal cancel_requested()                       # 返回上一级（目标选择 -> 菜单）

# ==============================================================
# 常量（ADR-4：640×360）
# ==============================================================
const VIEW_W := 640.0
const VIEW_H := 360.0

# 九宫格五色板（与 NineSlicePanel 默认值一致）
const C_BG := Color(0.10, 0.11, 0.15)
const C_FACE := Color(0.22, 0.24, 0.30)
const C_EDGE := Color(0.55, 0.58, 0.68)
const C_EDGE_DK := Color(0.33, 0.36, 0.44)
const C_HI := Color(0.95, 0.85, 0.30)

# 浮动数字五色（§4.6）
const C_DMG := Color(1.0, 1.0, 1.0)    # 白：普通伤害
const C_WEAK := Color(1.0, 0.60, 0.10) # 橙：克制（放大 1.3 倍，E3-S5 弹字）
const C_RES := Color(0.65, 0.65, 0.65) # 灰：抗性
const C_HEAL := Color(0.35, 0.95, 0.45) # 绿：回复
const C_POISON := Color(0.55, 0.95, 0.30) # 绿泡：中毒角标

# 阵营底色
const C_PARTY := Color(0.18, 0.28, 0.50)
const C_ENEMY := Color(0.50, 0.18, 0.18)

# 布局坐标（整数像素）
const PRED_Y := 6.0
const PRED_X := 8.0
const PRED_W := 624.0
const PRED_H := 34.0
const PRED_SLOT_W := 204.0

const ENEMY_BAR_Y := 46.0
const ENEMY_BAR_X0 := 168.0
const ENEMY_BAR_DX := 132.0
const ENEMY_BAR_W := 112.0
const ENEMY_BAR_H := 16.0

const STATUS_Y := 296.0
const STATUS_X0 := 168.0
const STATUS_DX := 156.0
const STATUS_W := 152.0
const STATUS_H := 58.0

const CMD_X := 8.0
const CMD_Y := 248.0
const CMD_W := 150.0
const CMD_H := 106.0

const DMG_LABEL_Y := 96.0

const RES_W := 360.0
const RES_H := 200.0

# ==============================================================
# 模型引用与子节点
# ==============================================================
const BattleLogic := preload("res://scripts/core/battle_logic.gd")
const BattleCommand := preload("res://scripts/battle/battle_command.gd")
const DataTables := preload("res://scripts/data/data_tables.gd")
const NineSlicePanel := preload("res://scripts/battle/nine_slice_panel.gd")
const BattleHitFeedback := preload("res://scripts/battle/battle_hit_feedback.gd")
const BattleBackground := preload("res://scripts/battle/battle_background.gd")
const BattleTransition := preload("res://scripts/battle/battle_transition.gd")

var cmd: BattleCommand = null

var _pred_bar: Control = null
var _pred_slots: Array[Panel] = []

var _cmd_menu: Control = null
var _cmd_buttons: Dictionary = {}        # type(String) -> Button
var _submenu: Control = null
var _submenu_list: VBoxContainer = null

var _status_bar: Control = null
var _status_cards: Array[Dictionary] = []  # slot -> {root, hp_fill, mp_fill, poison_icon, name_lbl}

var _enemy_layer: Control = null
var _enemy_bars: Array[Dictionary] = []    # idx -> {root, hp_fill, name_lbl, weak_icon, timer, shown}
var _enemy_bar_pos: Array[Vector2] = []

var _target_cursor: Panel = null
var _dmg_label: Label = null
var _float_layer: Control = null

var _result_panel: Control = null
var _result_label: Label = null

# E3-S5 层：背景 / 打击反馈 / 进战转场（均纯视图、脱离场景树可建）
# 注：三脚本均无 class_name，引用需为 Variant（动态分发），避免 headless 类型解析失败
var _battle_bg: Variant = null
var _hit_fx: Variant = null
var _transition: Variant = null

# 目标选择态
var _targets: Array[Dictionary] = []
var _cursor_idx: int = 0
var _command_pending: Dictionary = {}

var _built: bool = false


# ==============================================================
# 生命周期
# ==============================================================
func _ready() -> void:
	ensure_built()


## 构建静态节点骨架（一次性，可脱离场景树手动调用）
func ensure_built() -> void:
	if _built:
		return
	custom_minimum_size = Vector2(VIEW_W, VIEW_H)
	size = Vector2(VIEW_W, VIEW_H)
	_build()
	_built = true


## 绑定战斗模型：连接事件、刷新全部视图
func bind(bc: BattleCommand) -> void:
	ensure_built()
	cmd = bc
	if not cmd.event_emitted.is_connected(_on_battle_event):
		cmd.event_emitted.connect(_on_battle_event)
	if not cmd.battle_over.is_connected(_on_battle_over):
		cmd.battle_over.connect(_on_battle_over)
	refresh_all()


# ==============================================================
# 构建
# ==============================================================
func _build() -> void:
	# 背景（E3-S5：地图截图模糊+暗角，占位走纯色；set_screenshot 注入真实纹理）
	_battle_bg = BattleBackground.new()
	_battle_bg.name = "BattleBg"
	_battle_bg.ensure_built()
	add_child(_battle_bg)

	# §4.1 行动预告条
	_pred_bar = _make_panel("PredBar", PRED_X, PRED_Y, PRED_W, PRED_H)
	for i in 3:
		var slot := Panel.new()
		slot.name = "PredSlot%d" % i
		slot.position = Vector2(8.0 + float(i) * (PRED_SLOT_W + 4.0), 4.0)
		slot.size = Vector2(PRED_SLOT_W, PRED_H - 8.0)
		_pred_bar.add_child(slot)
		_pred_slots.append(slot)

	# §4.4 敌方信息层
	_enemy_layer = Control.new()
	_enemy_layer.name = "EnemyLayer"
	_enemy_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_layer)

	# §4.2 指令菜单
	_cmd_menu = _make_panel("CmdMenu", CMD_X, CMD_Y, CMD_W, CMD_H)
	var cmd_vbox := VBoxContainer.new()
	cmd_vbox.name = "CmdVBox"
	cmd_vbox.position = Vector2(8, 8)
	cmd_vbox.size = Vector2(CMD_W - 16, CMD_H - 16)
	_cmd_menu.add_child(cmd_vbox)
	_add_cmd_button(cmd_vbox, BattleCommand.CMD_ATTACK, "攻击")
	_add_cmd_button(cmd_vbox, BattleCommand.CMD_SKILL, "技能")
	_add_cmd_button(cmd_vbox, BattleCommand.CMD_ITEM, "道具")
	_add_cmd_button(cmd_vbox, BattleCommand.CMD_DEFEND, "防御")
	_add_cmd_button(cmd_vbox, BattleCommand.CMD_ESCAPE, "逃跑")

	# 技能/道具子菜单（默认隐藏）
	_submenu = _make_panel("SubMenu", CMD_X + CMD_W + 4, CMD_Y, 150.0, CMD_H)
	_submenu_list = VBoxContainer.new()
	_submenu_list.name = "SubList"
	_submenu_list.position = Vector2(8, 8)
	_submenu_list.size = Vector2(150.0 - 16, CMD_H - 16)
	_submenu.add_child(_submenu_list)
	_submenu.visible = false

	# §4.3 我方状态栏
	_status_bar = _make_panel("StatusBar", STATUS_X0, STATUS_Y, VIEW_W - STATUS_X0 - 8.0, STATUS_H)
	_build_status_cards()

	# §4.5 目标光标 + 预估伤害
	_target_cursor = Panel.new()
	_target_cursor.name = "TargetCursor"
	_target_cursor.visible = false
	add_child(_target_cursor)
	_dmg_label = Label.new()
	_dmg_label.name = "DmgRange"
	_dmg_label.position = Vector2((VIEW_W - 160.0) / 2.0, DMG_LABEL_Y)
	_dmg_label.size = Vector2(160.0, 18.0)
	_dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dmg_label.add_theme_font_size_override("font_size", 12)
	_dmg_label.visible = false
	add_child(_dmg_label)

	# §4.6 浮动数字层
	_float_layer = Control.new()
	_float_layer.name = "FloatLayer"
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)

	# E3-S5 打击反馈层（受击闪白 / 克制弹字），置于 HUD 之上、结算之下
	_hit_fx = BattleHitFeedback.new()
	_hit_fx.name = "HitFeedback"
	_hit_fx.ensure_built()
	add_child(_hit_fx)

	# §4.7 结算画面
	_result_panel = _make_panel("ResultPanel", (VIEW_W - RES_W) / 2.0,
			(VIEW_H - RES_H) / 2.0, RES_W, RES_H)
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_result_label.position = Vector2(16, 16)
	_result_label.size = Vector2(RES_W - 32, RES_H - 32)
	_result_label.add_theme_font_size_override("font_size", 13)
	_result_panel.add_child(_result_label)
	_result_panel.visible = false

	# E3-S5 进战转场层（黑屏淡入淡出）：置于最顶，遮挡全部 HUD 与战斗内容
	_transition = BattleTransition.new()
	_transition.name = "Transition"
	_transition.ensure_built()
	add_child(_transition)


func _make_panel(p_name: String, x: float, y: float, w: float, h: float) -> Control:
	var p := NineSlicePanel.new()
	p.name = p_name
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.configure(C_BG, C_FACE, C_EDGE, C_EDGE_DK, C_HI)
	p.build()
	add_child(p)
	return p


func _add_cmd_button(parent: VBoxContainer, type: String, label: String) -> void:
	var btn := Button.new()
	btn.name = "Btn_" + type
	btn.text = label
	btn.size = Vector2(CMD_W - 16, 16)
	btn.pressed.connect(_on_cmd_pressed.bind(type))
	parent.add_child(btn)
	_cmd_buttons[type] = btn


func _build_status_cards() -> void:
	for i in 3:
		var root := Control.new()
		root.name = "StatusCard%d" % i
		root.position = Vector2(8.0 + float(i) * STATUS_DX, 6.0)
		root.size = Vector2(STATUS_W - 8.0, STATUS_H - 8.0)
		_status_bar.add_child(root)

		var name_lbl := Label.new()
		name_lbl.name = "Name"
		name_lbl.position = Vector2(4, 2)
		name_lbl.add_theme_font_size_override("font_size", 10)
		root.add_child(name_lbl)

		var hp_bg := ColorRect.new()
		hp_bg.name = "HpBg"
		hp_bg.color = Color(0.25, 0.08, 0.08)
		hp_bg.position = Vector2(4, 18)
		hp_bg.size = Vector2(STATUS_W - 16, 8)
		root.add_child(hp_bg)
		var hp_fill := ColorRect.new()
		hp_fill.name = "HpFill"
		hp_fill.color = Color(0.85, 0.20, 0.20)
		hp_fill.position = Vector2(4, 18)
		hp_fill.size = Vector2(STATUS_W - 16, 8)
		root.add_child(hp_fill)

		var mp_bg := ColorRect.new()
		mp_bg.name = "MpBg"
		mp_bg.color = Color(0.08, 0.12, 0.30)
		mp_bg.position = Vector2(4, 30)
		mp_bg.size = Vector2(STATUS_W - 16, 6)
		root.add_child(mp_bg)
		var mp_fill := ColorRect.new()
		mp_fill.name = "MpFill"
		mp_fill.color = Color(0.30, 0.55, 0.95)
		mp_fill.position = Vector2(4, 30)
		mp_fill.size = Vector2(STATUS_W - 16, 6)
		root.add_child(mp_fill)

		var poison := ColorRect.new()
		poison.name = "PoisonIcon"
		poison.color = C_POISON
		poison.position = Vector2(STATUS_W - 18, 2)
		poison.size = Vector2(10, 10)
		poison.visible = false
		root.add_child(poison)

		_status_cards.append({"root": root, "hp_fill": hp_fill,
				"mp_fill": mp_fill, "poison_icon": poison, "name_lbl": name_lbl})


# ==============================================================
# 刷新（模型 -> 视图）
# ==============================================================
func refresh_all() -> void:
	refresh_prediction_bar()
	refresh_status_bar()
	refresh_command_menu()
	refresh_enemy_bars()


## §4.1 行动预告条：从 cmd.queue 取当前起 3 个行动者；击退后 cmd.queue 变化
## 本方法重读即刷新（也可经 _on_battle_event 自动触发）。
func refresh_prediction_bar() -> void:
	if cmd == null:
		return
	var prev: Array[Dictionary] = BattleLogic.preview(cmd.queue, cmd.cursor, 3)
	var actor: Dictionary = cmd.current_actor()
	for i in 3:
		var slot: Panel = _pred_slots[i]
		for c in slot.get_children().duplicate():
			c.free()
		if i >= prev.size():
			continue
		var e: Dictionary = prev[i] as Dictionary
		var u: Dictionary = BattleLogic.find_unit(cmd.party, cmd.enemies,
				String(e["side"]), int(e["slot"]))
		if u.is_empty():
			continue
		var side: String = String(u.get("side", ""))
		var bg := ColorRect.new()
		bg.color = C_PARTY if side == BattleLogic.SIDE_PARTY else C_ENEMY
		bg.size = slot.size
		slot.add_child(bg)
		var nm := Label.new()
		nm.text = String(u.get("name", ""))
		nm.add_theme_font_size_override("font_size", 10)
		nm.position = Vector2(3, 2)
		slot.add_child(nm)
		# 当前行动者高亮描边（§4.1：当前行动者描边高亮）
		if i == 0:
			var top := ColorRect.new()
			top.color = C_HI
			top.size = Vector2(slot.size.x, 2)
			slot.add_child(top)
			var bot := ColorRect.new()
			bot.color = C_HI
			bot.position = Vector2(0, slot.size.y - 2)
			bot.size = Vector2(slot.size.x, 2)
			slot.add_child(bot)


## §4.3 我方状态栏：HP/MP 条 + 中毒角标
func refresh_status_bar() -> void:
	if cmd == null:
		return
	for i in _status_cards.size():
		var card: Dictionary = _status_cards[i]
		if i >= cmd.party.size():
			card["root"].visible = false
			continue
		var u: Dictionary = cmd.party[i] as Dictionary
		card["root"].visible = true
		card["name_lbl"].text = "%s Lv%d" % [String(u.get("name", "")), int(u.get("level", 1))]
		var hp_ratio: float = float(u.get("hp", 0)) / maxf(1.0, float(u.get("max_hp", 1)))
		var mp_ratio: float = float(u.get("mp", 0)) / maxf(1.0, float(u.get("max_mp", 1)))
		var full_w: float = STATUS_W - 16.0
		(card["hp_fill"] as ColorRect).size.x = full_w * clampf(hp_ratio, 0.0, 1.0)
		(card["mp_fill"] as ColorRect).size.x = full_w * clampf(mp_ratio, 0.0, 1.0)
		(card["poison_icon"] as ColorRect).visible = int(u.get("poison_turns", 0)) > 0


## §4.2 指令菜单：可用项点亮、不可用项置灰（Boss 战逃跑禁用、空背包道具置灰）
func refresh_command_menu() -> void:
	if cmd == null:
		return
	var actor: Dictionary = cmd.current_actor()
	var show_menu: bool = cmd.is_party_turn() and not cmd.over
	_cmd_menu.visible = show_menu
	_submenu.visible = false
	if not show_menu:
		return
	var cmds: Array[String] = cmd.available_commands(actor)
	for type in _cmd_buttons.keys():
		var btn: Button = _cmd_buttons[type] as Button
		btn.disabled = not (type in cmds)


## §4.4 敌方信息：HP 条（受击显示，3s 淡出）+ 弱点图标
func refresh_enemy_bars() -> void:
	if cmd == null:
		return
	# 首次构建敌方条
	if _enemy_bars.is_empty() and not cmd.enemies.is_empty():
		for i in cmd.enemies.size():
			_enemy_bar_pos.append(_enemy_bar_pos_for(i))
			var root := Control.new()
			root.name = "EnemyBar%d" % i
			root.position = _enemy_bar_pos[i]
			root.size = Vector2(ENEMY_BAR_W, ENEMY_BAR_H + 14.0)
			_enemy_layer.add_child(root)
			var nm := Label.new()
			nm.name = "Name"
			nm.add_theme_font_size_override("font_size", 9)
			nm.position = Vector2(0, 0)
			root.add_child(nm)
			var hp_bg := ColorRect.new()
			hp_bg.color = Color(0.20, 0.06, 0.06)
			hp_bg.position = Vector2(0, 12)
			hp_bg.size = Vector2(ENEMY_BAR_W, ENEMY_BAR_H)
			root.add_child(hp_bg)
			var hp_fill := ColorRect.new()
			hp_fill.color = Color(0.90, 0.25, 0.25)
			hp_fill.position = Vector2(0, 12)
			hp_fill.size = Vector2(ENEMY_BAR_W, ENEMY_BAR_H)
			root.add_child(hp_fill)
			var wk := Label.new()
			wk.name = "WeakIcon"
			wk.text = "弱"
			wk.add_theme_font_size_override("font_size", 9)
			wk.position = Vector2(ENEMY_BAR_W - 14, 0)
			wk.visible = false
			root.add_child(wk)
			var tm := Timer.new()
			tm.name = "FadeTimer"
			tm.one_shot = true
			tm.wait_time = 3.0
			tm.timeout.connect(_on_enemy_fade.bind(i))
			root.add_child(tm)
			_enemy_bars.append({"root": root, "hp_fill": hp_fill,
					"name_lbl": nm, "weak_icon": wk, "timer": tm, "shown": false})
	# 更新数值
	for i in _enemy_bars.size():
		var e: Dictionary = cmd.enemies[i] as Dictionary
		var bar: Dictionary = _enemy_bars[i]
		(bar["name_lbl"] as Label).text = String(e.get("name", ""))
		var ratio: float = float(e.get("hp", 0)) / maxf(1.0, float(e.get("max_hp", 1)))
		(bar["hp_fill"] as ColorRect).size.x = ENEMY_BAR_W * clampf(ratio, 0.0, 1.0)
		# 弱点图标：敌人有弱点且该弱点已在跨战斗记忆中（§3.3 / §4.4）
		var wk: String = String(e.get("weakness", ""))
		(bar["weak_icon"] as Label).visible = (not wk.is_empty()) and cmd.discovered_weakness.has(wk)


func _enemy_bar_pos_for(idx: int) -> Vector2:
	return Vector2(ENEMY_BAR_X0 + float(idx) * ENEMY_BAR_DX, ENEMY_BAR_Y)


## §4.4：受击时显示敌方 HP 条，3s 后淡出
func show_enemy_hp(idx: int) -> void:
	if idx < 0 or idx >= _enemy_bars.size():
		return
	var bar: Dictionary = _enemy_bars[idx]
	(bar["root"] as Control).modulate.a = 1.0
	bar["shown"] = true
	var tm: Timer = bar["timer"] as Timer
	if tm.is_stopped():
		tm.start()


func _on_enemy_fade(idx: int) -> void:
	if idx < 0 or idx >= _enemy_bars.size():
		return
	(bar_get(idx)["root"] as Control).modulate.a = 0.25


func bar_get(idx: int) -> Dictionary:
	return _enemy_bars[idx] as Dictionary


# ==============================================================
# 目标选择（§4.5）
# ==============================================================
func _enter_targeting(command: Dictionary) -> void:
	_targets = cmd.targets_for(command)
	if _targets.is_empty():
		return
	_command_pending = command
	_cursor_idx = 0
	_target_cursor.visible = true
	_update_target_cursor()


func _update_target_cursor() -> void:
	if _targets.is_empty():
		return
	_cursor_idx = wrapi(_cursor_idx, 0, _targets.size())
	var tgt: Dictionary = _targets[_cursor_idx] as Dictionary
	var pos: Vector2 = _target_screen_pos(tgt)
	_target_cursor.position = pos - Vector2(4, 4)
	_target_cursor.size = Vector2(12, 12)
	# 预估伤害区间（"— 24~29 —" 格式；UI 也是玩家验证克制的工具）
	var actor: Dictionary = cmd.current_actor()
	_dmg_label.text = format_damage_range(predict_for(actor, tgt, _command_pending))
	_dmg_label.visible = true


func _target_screen_pos(tgt: Dictionary) -> Vector2:
	if String(tgt.get("side", "")) == BattleLogic.SIDE_ENEMY:
		return _enemy_bar_pos_for(int(tgt.get("slot", 0))) + Vector2(ENEMY_BAR_W / 2.0, ENEMY_BAR_H / 2.0 + 6.0)
	# 我方目标：对应状态卡中心
	var sidx: int = int(tgt.get("slot", 0))
	return Vector2(STATUS_X0 + 8.0 + float(sidx) * STATUS_DX + (STATUS_W - 8.0) / 2.0,
			STATUS_Y + STATUS_H / 2.0)


func move_cursor(dir: int) -> void:
	_cursor_idx += dir
	_update_target_cursor()


## 确认目标：连同 target_slot 一并回传
func confirm_target() -> void:
	if _targets.is_empty():
		return
	var tgt: Dictionary = _targets[_cursor_idx] as Dictionary
	var out: Dictionary = _command_pending.duplicate()
	out["target_slot"] = int(tgt.get("slot", -1))
	_target_cursor.visible = false
	_dmg_label.visible = false
	_targets = []
	command_selected.emit(out)


func cancel_targeting() -> void:
	_target_cursor.visible = false
	_dmg_label.visible = false
	_targets = []
	_command_pending = {}
	cancel_requested.emit()


# ==============================================================
# 指令菜单交互
# ==============================================================
func _on_cmd_pressed(type: String) -> void:
	match type:
		BattleCommand.CMD_ATTACK:
			_enter_targeting({"type": BattleCommand.CMD_ATTACK})
		BattleCommand.CMD_SKILL:
			_open_skill_submenu()
		BattleCommand.CMD_ITEM:
			_open_item_submenu()
		BattleCommand.CMD_DEFEND:
			command_selected.emit({"type": BattleCommand.CMD_DEFEND})
		BattleCommand.CMD_ESCAPE:
			command_selected.emit({"type": BattleCommand.CMD_ESCAPE})


func _open_skill_submenu() -> void:
	for c in _submenu_list.get_children().duplicate():
		c.free()
	var actor: Dictionary = cmd.current_actor()
	var cid: String = String(actor.get("unit_id", ""))
	var cd: Variant = DataTables.get_character(cid)
	if cd == null:
		_submenu.visible = false
		return
	var lv: int = int(actor.get("level", 1))
	var mp: int = int(actor.get("mp", 0))
	for lvl in cd.skills_by_level:
		if int(lvl) <= lv:
			for sid: String in cd.skills_by_level[lvl]:
				var sk: Variant = DataTables.get_skill(sid)
				if sk == null:
					continue
				var b := Button.new()
				b.name = "Skill_" + sid
				b.text = "%s(%dMP)" % [sk.name, sk.mp_cost]
				b.disabled = mp < sk.mp_cost
				b.pressed.connect(_on_submenu_pressed.bind({"type": BattleCommand.CMD_SKILL, "skill_id": sid}))
				_submenu_list.add_child(b)
	_submenu.visible = true


func _open_item_submenu() -> void:
	for c in _submenu_list.get_children().duplicate():
		c.free()
	for entry: Dictionary in cmd.available_items():
		var item: Variant = DataTables.get_item(String(entry.get("item_id", "")))
		var b := Button.new()
		b.name = "Item_" + String(entry.get("item_id", ""))
		b.text = "%s x%d" % [item.name if item != null else "?", int(entry.get("count", 0))]
		b.pressed.connect(_on_submenu_pressed.bind({"type": BattleCommand.CMD_ITEM,
				"item_id": String(entry.get("item_id", ""))}))
		_submenu_list.add_child(b)
	_submenu.visible = true


func _on_submenu_pressed(payload: Dictionary) -> void:
	_submenu.visible = false
	_enter_targeting(payload)


# ==============================================================
# 预估伤害区间（复用 BattleLogic 真值，避免 UI 与结算常量漂移）
# ==============================================================
func predict_for(actor: Dictionary, target: Dictionary, command: Dictionary) -> Vector2i:
	var dmg_mult: float = BattleLogic.incoming_damage_multiplier(
			bool(target.get("defending", false)), bool(target.get("covering", false)))
	if command.get("type") == BattleCommand.CMD_SKILL:
		var sk: Variant = DataTables.get_skill(String(command.get("skill_id", "")))
		if sk != null:
			var power: float = float(sk.power)
			if String(sk.kind) == "magic":
				return BattleLogic.magic_damage_range(int(actor.get("mag", 0)),
						int(target.get("def", 0)), power, String(sk.element),
						String(target.get("weakness", "")), String(target.get("resist", "")), dmg_mult)
			return BattleLogic.physical_damage_range(int(actor.get("atk", 1)),
					int(target.get("def", 0)), power, dmg_mult)
	return BattleLogic.physical_damage_range(int(actor.get("atk", 1)),
			int(target.get("def", 0)), 1.0, dmg_mult)


## §4.5 格式："— 24~29 —"
func format_damage_range(r: Vector2i) -> String:
	return "— %d~%d —" % [r.x, r.y]


# ==============================================================
# 浮动数字（§4.6 五色）
# ==============================================================
func spawn_damage_number(pos: Vector2, amount: int, kind: String) -> void:
	var color: Color = C_DMG
	match kind:
		"weak": color = C_WEAK
		"resist": color = C_RES
		"heal": color = C_HEAL
		"poison": color = C_POISON
	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(lbl)


# ==============================================================
# 结算画面（§4.7）
# ==============================================================
func show_result(result: Dictionary) -> void:
	_result_panel.visible = true
	var lines := PackedStringArray()
	lines.append("—— 战斗结算 ——")
	match String(result.get("outcome", "")):
		BattleCommand.OUTCOME_VICTORY: lines.append("胜利！")
		BattleCommand.OUTCOME_DEFEAT: lines.append("全灭……")
		BattleCommand.OUTCOME_ESCAPE: lines.append("成功撤退")
	for ps in result.get("party_state", []):
		var d: Dictionary = ps as Dictionary
		lines.append("%s  HP %d/%d  MP %d/%d" % [String(d.get("name", "")),
				int(d.get("hp", 0)), int(d.get("max_hp", 0)),
				int(d.get("mp", 0)), int(d.get("max_mp", 0))])
	_result_label.text = "\n".join(lines)


# ==============================================================
# 查询接口（供测试/E3-S5 集成断言；避免外部直接戳私有成员）
# ==============================================================
func get_prediction_names() -> Array[String]:
	var out: Array[String] = []
	for i in _pred_slots.size():
		var nm := ""
		for c in _pred_slots[i].get_children():
			if c is Label:
				nm = c.text
		out.append(nm)
	return out


# 八要素节点存在性（供测试断言"逐项在场"）
func has_pred_bar() -> bool: return _pred_bar != null
func has_cmd_menu() -> bool: return _cmd_menu != null
func has_status_bar() -> bool: return _status_bar != null
func has_enemy_layer() -> bool: return _enemy_layer != null
func has_target_cursor() -> bool: return _target_cursor != null
func has_dmg_label() -> bool: return _dmg_label != null
func has_float_layer() -> bool: return _float_layer != null
func has_result_panel() -> bool: return _result_panel != null


func get_prediction_slot_count() -> int:
	return _pred_slots.size()


func get_status_card_count() -> int:
	return _status_cards.size()


func get_enemy_bar_count() -> int:
	return _enemy_bars.size()


func is_command_disabled(type: String) -> bool:
	var b: Button = _cmd_buttons.get(type, null) as Button
	if b == null:
		return true
	return b.disabled


func get_float_count() -> int:
	return _float_layer.get_child_count()


func get_float_text(idx: int) -> String:
	var c: Label = _float_layer.get_child(idx) as Label
	return c.text


func is_result_visible() -> bool:
	return _result_panel.visible


func get_result_text() -> String:
	return _result_label.text


func cmd_menu_patch_count() -> int:
	return _cmd_menu.get_child_count()


func status_bar_patch_count() -> int:
	return _status_bar.get_child_count()


func result_panel_patch_count() -> int:
	return _result_panel.get_child_count()


# ==============================================================
# 事件桥接（模型事件 -> 视图刷新；击退后预告条立即刷新）
# ==============================================================
func _on_battle_event(e: Dictionary) -> void:
	var t: String = String(e.get("type", ""))
	if t == "damage" or t == "weakness":
		var pos: Vector2 = _event_screen_pos(e)
		if t == "damage":
			# 受击浮动数字（克制走橙字字色）
			var kind: String = "normal"
			if bool(e.get("weak", false)):
				kind = "weak"
			spawn_damage_number(pos, int(e.get("amount", 0)), kind)
			# 受击闪白（E3-S5）
			if _hit_fx != null:
				_hit_fx.trigger_flash()
		elif t == "weakness":
			# 首见弱点：弹"弱点！" + 写入跨战斗记忆（§3.3）
			if _hit_fx != null:
				_hit_fx.spawn_weak_popup(pos)
				_hit_fx.record_weakness(String(e.get("element", "")))
	refresh_prediction_bar()
	refresh_status_bar()
	refresh_enemy_bars()


## 事件目标屏幕坐标（damage/weakness 的 side/slot 决定落点）
func _event_screen_pos(e: Dictionary) -> Vector2:
	var side: String = String(e.get("side", ""))
	var slot: int = int(e.get("slot", -1))
	if side == BattleLogic.SIDE_ENEMY:
		return _enemy_bar_pos_for(slot) + Vector2(ENEMY_BAR_W / 2.0, ENEMY_BAR_H / 2.0 + 6.0)
	return Vector2(STATUS_X0 + 8.0 + float(slot) * STATUS_DX + (STATUS_W - 8.0) / 2.0,
			STATUS_Y + STATUS_H / 2.0)


func _on_battle_over(result: Dictionary) -> void:
	show_result(result)


# ==============================================================
# E3-S5 查询接口（供测试断言；避免外部直接戳私有成员）
# ==============================================================
func has_background() -> bool:
	return _battle_bg != null


func has_hit_feedback() -> bool:
	return _hit_fx != null


func has_transition() -> bool:
	return _transition != null


func get_flash_alpha() -> float:
	if _hit_fx == null:
		return 0.0
	return float(_hit_fx.get_flash_alpha())


func get_weak_popup_count() -> int:
	if _hit_fx == null:
		return 0
	return int(_hit_fx.get_popup_count())


func get_weak_popup_text(idx: int) -> String:
	if _hit_fx == null:
		return ""
	return String(_hit_fx.get_popup_text(idx))


## 注入地图截图到背景层（E4 探索侧接入真实纹理时调用）
func set_battle_screenshot(tex: Texture2D) -> void:
	if _battle_bg != null:
		_battle_bg.set_screenshot(tex)


func get_battle_screenshot() -> Variant:
	if _battle_bg == null:
		return null
	return _battle_bg.get_screenshot()


func is_transition_playing() -> bool:
	if _transition == null:
		return false
	return bool(_transition.is_playing())


func get_transition_black_alpha() -> float:
	if _transition == null:
		return 0.0
	return float(_transition.get_black_alpha())


func play_transition_intro() -> void:
	if _transition != null:
		_transition.play_intro()
