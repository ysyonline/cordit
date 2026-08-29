extends Node2D
## battle_scene —— 占位战斗场景（E2-S3，架构 A4/A5 + C2 第 2 周练习 4）
##
## 【定位】"战斗是假的，数据流必须是真的"（EPIC-2 里程碑门 M2 本质）：
##   本场景验证 A5 载荷闭环的中段——从 SceneRouter 暂存区取 BattlePayload，
##   据 enemy_group_id 摆彩色方块阵（纯视觉区分，无敌人数值表），
##   从 GameData 直读队伍初始态显示，胜利/失败按钮发 BattleResult。
##   真实战斗逻辑属 EPIC-3；GameData 覆写属 E2-S4——本场景【只读不写】。
##
## 【边界】（A3/A5）：
##   - 载荷唯一来源：SceneRouter.get_staged_payload()（A3"载荷暂存"的
##     唯一读取口），不经信号旁路、不引用地图场景；
##   - 只读 GameData.party 显示（战斗侧读队伍初始态，A5）；零写回——
##     战后覆写由 E2-S4 消费本场景发出的 battle_finished 载荷后执行；
##   - 不感知地图：return_map/return_position 仅原样保留在结果载荷之外
##     （E2-S4 写回时按 BattleResult 协议另行组装），本场景自己不切场景；
##   - 引用风格：preload 常量（项目规范，见 character_record.gd 头注释）。
##
## 【9 格阵规则】（本 Story 无敌人数值表，纯函数区分）：
##   enemy_group_id 为空 → 9 格灰阵（防御式显示）；
##   非空 → 方块数 = 3 + 哈希 % 7（3~9 个），色相 = 哈希派生；
##   同 group_id 恒得同阵型同配色（哈希稳定，可复现可调试）。

## 队伍角色记录类型（preload 常量，项目规范）
const CharacterRecord := preload("res://scripts/core/character_record.gd")

## 方块阵规格（占位视觉：3x3 网格、28px 方块、12px 间距，ADR-4 像素口径）
const GRID_COLS: int = 3
const BLOCK_SIZE: float = 28.0
const BLOCK_GAP: float = 12.0

## 方块阵列数上限（3 格基础 + 最多 6 格派生 = 9 格满阵）
const MAX_BLOCKS: int = 9

## 最近一次消费的 BattlePayload（测试与调试观察口；不入存档协议）
var last_payload: Dictionary = {}

## 方块容器（测试定位用）
var _blocks_root: Node2D = null

## 队伍状态文本（占位 UI：3 角色 HP/MP 行）
var _party_label: Label = null


func _ready() -> void:
	# 消费暂存载荷（Router 校验闸门在切换前已把关，此处只管消费）
	last_payload = SceneRouter.get_staged_payload()
	_build_ui()
	_spawn_enemy_blocks(String(last_payload.get("enemy_group_id", "")))
	_show_party_state()
	print("[BattleScene] 就绪：编组=%s 回图=%s 队伍=%d 人" % [
			last_payload.get("enemy_group_id", "<空>"),
			last_payload.get("return_map", "<空>"),
			GameData.party.size()])


# ------------------------------------------------------------------
# 占位 UI 组建（一次性；纯色背景 + 方块阵 + 队伍状态 + 两按钮）
# ------------------------------------------------------------------

func _build_ui() -> void:
	# 纯色背景（C2 练习 4 占位口径；CanvasItem 直绘在 Node2D 世界层）
	var bg := ColorRect.new()
	bg.name = "BattleBackdrop"
	bg.color = Color(0.12, 0.12, 0.16)
	bg.offset_right = 640.0
	bg.offset_bottom = 360.0
	add_child(bg)

	# 敌方方块阵容器（居中偏上）
	_blocks_root = Node2D.new()
	_blocks_root.name = "EnemyBlocks"
	_blocks_root.position = Vector2(320, 110)
	add_child(_blocks_root)

	# 我方队伍状态（占位 Label，正式版由 EPIC-3 战斗 UI 替换）
	_party_label = Label.new()
	_party_label.name = "PartyState"
	_party_label.position = Vector2(24, 200)
	_party_label.size = Vector2(400, 120)
	_party_label.add_theme_font_size_override("font_size", 10)
	add_child(_party_label)

	# 胜利 / 失败按钮（占位结局模拟；真实指令菜单属 EPIC-3）
	_make_button("BtnVictory", "胜利", Vector2(480, 280), true)
	_make_button("BtnDefeat", "失败", Vector2(560, 280), false)


func _make_button(btn_name: String, text: String, pos: Vector2, is_victory: bool) -> void:
	var btn := Button.new()
	btn.name = btn_name
	btn.text = text
	btn.position = pos
	btn.size = Vector2(64, 28)
	btn.pressed.connect(_on_outcome_pressed.bind(is_victory))
	add_child(btn)


# ------------------------------------------------------------------
# 敌方方块阵（group_id -> 阵型/配色的纯函数映射）
# ------------------------------------------------------------------

## 群组 id -> 方块数（3~9）。空 id 按 0 处理（防御式：调用方决定显示灰阵）。
func get_block_count(group_id: String) -> int:
	if group_id.is_empty():
		return 0
	return 3 + (_hash_group(group_id) % 7)


## 群组 id -> 色相偏移（0.0~1.0，哈希派生）
func get_block_hue(group_id: String) -> float:
	return float(_hash_group(group_id) % 360) / 360.0


## 稳定字符串哈希（DJB2 变体：逐字符乘 33 累加，32 位溢出回绕）。
## 不用内置 hash()：其跨版本/跨平台稳定性无保证，阵型可复现优先。
func _hash_group(group_id: String) -> int:
	var h: int = 5381
	for ch: String in group_id:
		h = int((h * 33 + ch.unicode_at(0)) % 2147483647)
	return h


## 按 group_id 摆方块阵：3x3 网格居中；空 id 摆 9 格灰阵（占位防御态）
func _spawn_enemy_blocks(group_id: String) -> void:
	var count: int = get_block_count(group_id)
	var hue: float = get_block_hue(group_id)
	if group_id.is_empty():
		count = MAX_BLOCKS  # 无编组信息时按满阵灰块显示，暴露"载荷异常"而非静默空白
	for i: int in count:
		var col: int = i % GRID_COLS
		var row: int = i / GRID_COLS
		var block := ColorRect.new()
		block.name = "Block%d" % i
		var cell_w: float = BLOCK_SIZE + BLOCK_GAP
		var grid_w: float = cell_w * GRID_COLS - BLOCK_GAP
		block.position = Vector2(-grid_w / 2.0 + col * cell_w,
				-1.5 * cell_w + row * cell_w)
		block.size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
		if group_id.is_empty():
			block.color = Color(0.35, 0.35, 0.35)
		else:
			# HSV 色相环派生（同 group 恒同色；饱和度/明度固定保证可读性）
			block.color = Color.from_hsv(hue, 0.65, 0.9)
		_blocks_root.add_child(block)


# ------------------------------------------------------------------
# 队伍初始态显示（A5：战斗场景从 GameData 读队伍初始态）
# ------------------------------------------------------------------

func _show_party_state() -> void:
	var lines: Array[String] = []
	lines.append("── 我方队伍（直读 GameData.party）──")
	for i: int in GameData.party.size():
		var c: CharacterRecord = GameData.party[i]
		lines.append("[%d] %s（%s）Lv%d  HP %d/%d  MP %d/%d" % [
				i, c.name, c.job, c.level, c.hp, c.max_hp, c.mp, c.max_mp])
	_party_label.text = "\n".join(lines)


# ------------------------------------------------------------------
# 结局模拟（A5 BattleResult：本场景只发结果，覆写 GameData 属 E2-S4）
# ------------------------------------------------------------------

func _on_outcome_pressed(is_victory: bool) -> void:
	var outcome: String = "VICTORY" if is_victory else "DEFEAT"
	EventBus.battle_finished.emit(_build_result(outcome))
	print("[BattleScene] 结局模拟 -> %s（party_state 占位 %d 条）" % [
			outcome, GameData.party.size()])


## 组装 A5 BattleResult：outcome + party_state（GameData 当前态的快照，
## 结构占位、数值真实——E2-S4 据此覆写；exp/gold 结算字段留空数组）。
func _build_result(outcome: String) -> Dictionary:
	var party_state: Array = []
	for c: CharacterRecord in GameData.party:
		party_state.append({
			"id": c.id,
			"level": c.level,
			"hp": c.hp,
			"max_hp": c.max_hp,
			"mp": c.mp,
			"max_mp": c.max_mp,
		})
	return {
		"outcome": outcome,
		"party_state": party_state,
		"exp_gained": [],
		"gold_gained": 0,
		"items_used": [],
	}
