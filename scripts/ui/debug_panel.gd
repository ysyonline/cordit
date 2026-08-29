extends CanvasLayer
## DebugPanel —— M 键调试面板（E2-S1 / C2 第 2 周练习 3）
##
## 引用方式：preload 常量（本文件下方）；不用全局 class_name——理由同
## scripts/core/character_record.gd 头注释（headless 跑测通道即时可用）。
##
## 【职责】只读展示运行时状态：GameData 全字段 + 队伍 3 角色数值。
##   数据"实时刷新"策略：_process 轮询（0.15s 节流）重写一次 BBCode 文本，
##   面板控件树在 _ready 一次性建好——每帧只更新字符串，绝不重建控件
##   （重建节点树会引发整层重排，是 UI 卡顿的典型成因）。
##
## 【边界】
##   - 纯 UILayer 节点：继承 CanvasLayer（独立于世界画布），挂载点为
##     main.tscn 的 UILayer 下；只读 GameData，不写任何游戏状态、不发任何
##     业务信号（A3：数据只进 UI，UI 不回注）；
##   - 不拦截游戏输入：除 M 键外不消费任何输入事件；整棵控件树
##     mouse_filter = IGNORE（鼠标穿透），也不获取键盘焦点——玩家按 WASD
##     移动、Z/E 对话不受面板开合影响；
##   - 无每帧分配的稳态：面板关闭时 _process 直接返回（仍有 M 键监听，
##     但零字符串构造、零 GC 压力）。
##
## 【M 键接线】双保险：
##   1. 首选项目级输入动作 "debug_panel"（project.godot [input]，physical M）；
##   2. 动作缺失时回退直查物理键 KEY_M（保证脚本单测/任意工程配置下可 toggle）。
##   若 Ctrl 按住则放行不吞（预留调试组合键空间）；面板不持有游戏状态，
##   _visible 是纯显示状态（UI 不持有游戏状态，路径作用域编码标准）。

## 队伍角色记录类型（preload 常量，不用全局 class_name，理由见头注释）
const CharacterRecord := preload("res://scripts/core/character_record.gd")

## 项目级输入动作名（project.godot [input] 段；缺失时回退 KEY_M 直查）
const TOGGLE_ACTION: String = "debug_panel"

## 文本刷新间隔（秒）——"实时"的人眼阈值以下，同时把重绘频率压到 ~7 次/秒
const REFRESH_INTERVAL: float = 0.15

## 面板矩形内边距（640×360 像素视口，ADR-4 像素口径）
const PANEL_MARGIN: float = 6.0

## 距上次刷新的累计秒数（轮询节流用）
var _since_refresh: float = 0.0

## 状态只读展示区（BBCode 富文本）
var _text: RichTextLabel


func _ready() -> void:
	# 层号与宿主 UILayer 常驻层一致（main.tscn 中 UILayer layer=10），
	# 保证面板作为 UILayer 子层时渲染层级关系与注释/文档口径一致。
	layer = 10
	# 面板默认关闭：调试工具不得影响首屏画面与试玩录像
	visible = false
	_build_ui()


## 组建控件树（仅启动时执行一次）。
## 根 ColorRect 作半透明底（世界画面可透出，读数不致与场景混色）；
## 全部控件 mouse_filter = IGNORE —— 面板对鼠标完全透明（验收点 2：
## 纯 UILayer、不影响游戏世界，含不吞鼠标点击）。
func _build_ui() -> void:
	var root := ColorRect.new()
	root.name = "DebugPanelRoot"
	root.color = Color(0.0, 0.0, 0.0, 0.55)  # 半透明黑底，白盒阶段通用配色
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_text = RichTextLabel.new()
	_text.name = "StateText"
	_text.bbcode_enabled = true          # 用 BBCode 上色：数值异常一眼可辨
	_text.scroll_active = false          # 不出滚动条（内容按 640×360 版式精排）
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.focus_mode = Control.FOCUS_NONE  # 不抢键盘焦点（WASD 移动不受影响）
	# 满铺 + 四边内缩 PANEL_MARGIN：相对底板留出呼吸边距（640×360 像素视口）
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = PANEL_MARGIN
	_text.offset_top = PANEL_MARGIN
	_text.offset_right = -PANEL_MARGIN
	_text.offset_bottom = -PANEL_MARGIN
	root.add_child(_text)


## 输入入口：只处理 M 键开/关（toggle），其余事件一律放行不消费。
## _unhandled_input 而非 _input：游戏输入（玩家移动等）经 _input 被场景消费，
## 走 _unhandled_input 可保证面板不与游戏抢事件；M 键在此处 set_input_as_handled
## 防止同一次按键又漏进游戏逻辑。
func _unhandled_input(event: InputEvent) -> void:
	if _is_toggle_pressed(event):
		toggle()
		get_viewport().set_input_as_handled()


## M 键判定（含 project.godot 动作缺失时的 KEY_M 回退）。
## 仅认"刚按下"（pressed 且非 echo），按住不放只触发一次。
func _is_toggle_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		# Ctrl 按住时放行：为未来"Ctrl+M"类调试组合键留扩展位
		if event.ctrl_pressed:
			return false
		if InputMap.has_action(TOGGLE_ACTION) and event.is_action_pressed(TOGGLE_ACTION):
			return true
		# 回退通道：工程未注册 debug_panel 动作时按物理 M 键直判
		if (event as InputEventKey).physical_keycode == KEY_M:
			return true
	return false


## 开/关切换（toggle）。暴露为公开方法：GUT 直接调它验证切换逻辑，
## 人工测试时也可被其他调试代码安全调用。
func toggle() -> void:
	visible = not visible
	# 打开瞬间立即刷一帧：避免最长 0.15s 显示上一次关闭前的旧数据
	if visible:
		_since_refresh = REFRESH_INTERVAL
		_refresh_text()


## 每帧轮询（节流）：面板开着才重建字符串；关闭时零开销直返。
func _process(delta: float) -> void:
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_INTERVAL:
		_since_refresh = 0.0
		_refresh_text()


## 重写只读文本：GameData 全字段 + 队伍 3 角色数值。
## 全中文标签；数值异常（HP>上限 / HP<=0）标红，调试时一眼定位脏数据。
func _refresh_text() -> void:
	var lines: Array[String] = []
	lines.append("[b]══ 调试面板 · 运行时状态（M 键开关）══[/b]")

	# —— 队伍 3 角色（槽位序：剑士→术士→辅助）——
	lines.append("[b]── 队伍（%d 人）──[/b]" % GameData.party.size())
	for i: int in GameData.party.size():
		var c: CharacterRecord = GameData.party[i]
		var hp_bad: bool = c.hp > c.max_hp or c.hp <= 0
		var mp_bad: bool = c.mp > c.max_mp or c.mp < 0
		lines.append("[%d] %s（%s）Lv%d  HP %d/%s  MP %d/%s" % [
				i, c.name, c.job, c.level, c.hp, String.num(c.max_hp, 0),
				c.mp, String.num(c.max_mp, 0)])
		if hp_bad:
			lines[-1] += "  [color=#ff5555]HP 异常[/color]"
		if mp_bad:
			lines[-1] += "  [color=#ff5555]MP 异常[/color]"

	# —— GameData 其余全字段（与 SMK-06 字段清单一一对应，防遗漏）——
	lines.append("[b]── 全局状态 ──[/b]")
	lines.append("背包 inventory: %s" % _fmt_dict(GameData.inventory))
	lines.append("金钱 gold: %d" % GameData.gold)
	lines.append("剧情阶段 story_phase: %d" % GameData.story_phase)
	lines.append("剧情标志 flags: %s" % _fmt_dict(GameData.flags))
	lines.append("已开宝箱 chests_opened: %s" % _fmt_set(GameData.chests_opened))
	lines.append("已清敌人 cleared_enemy_set: %s" % _fmt_set(GameData.cleared_enemy_set))
	lines.append("弱点记忆 discovered_weakness_set: %s" % _fmt_set(GameData.discovered_weakness_set))

	_text.text = "".join(lines)


## Dictionary 紧凑展示（"k=1, k2=2"；空显示 {}）
func _fmt_dict(d: Dictionary) -> String:
	if d.is_empty():
		return "{}"
	var parts: Array[String] = []
	for k: Variant in d:
		parts.append("%s=%s" % [k, d[k]])
	return "{ " + ", ".join(parts) + " }"


## Array 集合紧凑展示（"[a, b]"；空显示 []）
func _fmt_set(arr: Array) -> String:
	if arr.is_empty():
		return "[]"
	var parts: Array[String] = []
	for v: Variant in arr:
		parts.append(str(v))
	return "[ " + ", ".join(parts) + " ]"
