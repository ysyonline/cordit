extends Control
## dialogue_box.gd —— 对话框 UI 完整版（E5-S1，对话 GDD §4 + UI 规格 §二）
##
## 【升级自】E1-S6 最小版（名字栏 + 文本区 + 逐字提示）。本版按 UI 布局规格
##   §二冻结坐标补齐对话框五要素：名字栏 / 头像窗 48×48 / 文本区 / 继续箭头 /
##   选项列表。坐标全部取 ui-layout-specs.md §2.1（白盒阶段先 Control 面板色块
##   落位，九宫格窗体/字体精修随美术线，坐标契约不随精修变）。
##
## 【职责边界】纯展示层：只接受喂数接口，不读 JSON、不持有对话状态（状态在
##   DialogueRunner，A7 UI 分工）；逐字计时也在 runner——本层不做 Timer。
##   选项交互回传用"选中信号"，runner 连接后消费——UI 不持有游戏状态。
##
## 【选项交互契约】（GDD 边缘 4：选项必选其一，取消/移动键忽略）
##   打开选项列表后：↑/↓（move_up/move_down）移光标、interact 确认。
##   UI 侧消费这些输入并只发 choice_selected(idx)——没有"取消/关闭"路径，
##   玩家必须显式选一项（不响应 ui_cancel；Godot 无注册 ui_cancel 动作，
##   本层也不轮询它，双保险）。runner 在 WAITING_CHOICE 态把按键路由进来
##   （handle_choice_input），生产输入与测试注入同通道。
##
## 【按钮 2 语义】对话键位只有 interact 一个动作（Z/E）：逐字中按 = 补完，
##   已完成按 = 翻页/确认——"按键 1/按键 2"在单键动作下自然合并（最小版
##   既有行为，GDD §4 节奏目标不变；X/返回键按规格"对话不可跳回"不接线）。
##
## 【头像窗】48×48 原生零缩放（UI 规格冻结：64×64 非整数放大禁）；portrait
##   字段缺省 = 沿用上一条（GDD §3.1），由 runner 侧记忆并只在变化时调
##   set_portrait；未知/空 id → 隐藏头像窗，文本区左移补位（旁白无头像）。

const PortraitCatalog := preload("res://scripts/dialogue/portrait_catalog.gd")

## 继续箭头闪烁周期（UI 规格 §2.1：0.5s 周期闪烁）
const CONTINUE_BLINK_PERIOD: float = 0.5

## UI 规格冻结坐标（§2.1）：主体窗 (16,244,608,108)（锚点布局见 tscn）、
## 名字栏 (24,224,96,20)、头像窗 (24,252,88,88) 内嵌 48×48 居中、
## 文本区 x∈[128,612]、选项窗 (448,168,176,68)
const NAME_BAR_RECT := Rect2(8, -20, 96, 20)      # 相对主体窗 (24,224) - (16,244)
const PORTRAIT_BOX_RECT := Rect2(8, 8, 88, 88)    # 相对主体窗 (24,252) - (16,244)
const TEXT_RECT := Rect2(112, 12, 484, 84)        # 相对主体窗：x=128-16, 宽 484
const CHOICES_WINDOW_RECT := Rect2(448, -76, 176, 68)  # 主体窗上沿 244−8−68=168 → 相对 -76

signal choice_selected(index: int)

@onready var _panel: Panel = $Panel
@onready var _speaker_bar: PanelContainer = $Panel/SpeakerBar
@onready var _speaker_label: Label = $Panel/SpeakerBar/SpeakerLabel
@onready var _portrait_frame: Panel = $Panel/PortraitFrame
@onready var _portrait_rect: TextureRect = $Panel/PortraitFrame/PortraitRect
@onready var _text_label: RichTextLabel = $Panel/TextLabel
@onready var _continue_hint: Label = $Panel/ContinueHint
@onready var _choices_window: Panel = $ChoicesWindow
@onready var _choice_labels: Array[Label] = [
	$ChoicesWindow/Margin/VBox/Choice0, $ChoicesWindow/Margin/VBox/Choice1,
]

## 选项光标位置（open_choices 时重置为 0）
var _choice_cursor: int = 0

## 选项是否打开（打开时 _input 消费方向/确认键，抑制箭头闪烁以外的更新）
var _choices_open: bool = false


func _ready() -> void:
	# 初始隐藏；visible 由 open/close 管理（对话期间其他 UI 交互不受影响）
	visible = false
	_choices_window.visible = false
	_continue_hint.visible = false
	# 头像 48×48 原生零缩放（禁 64×64 非整数放大，UI 规格冻结口径）
	_portrait_rect.custom_minimum_size = Vector2(PortraitCatalog.CELL_SIZE, PortraitCatalog.CELL_SIZE)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _process(_delta: float) -> void:
	# 继续箭头 0.5s 周期闪烁（UI 规格 §2.1；用引擎时隙避免自建 Timer 装配）
	if _continue_hint.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_continue_hint.modulate.a = 1.0 if fmod(t, CONTINUE_BLINK_PERIOD * 2.0) < CONTINUE_BLINK_PERIOD else 0.25


# ------------------------------------------------------------------
# 开关与喂数接口（runner 消费面）
# ------------------------------------------------------------------

## 开框
func open() -> void:
	visible = true
	_continue_hint.visible = false
	_close_choices()


## 关框（含选项窗与光标态复位）
func close() -> void:
	visible = false
	_continue_hint.visible = false
	_close_choices()


## 设置名字栏内容；空串 = 旁白 → 隐藏名字栏（GDD §3.1）
func set_speaker(p_speaker: String) -> void:
	_speaker_label.text = p_speaker
	_speaker_bar.visible = not p_speaker.is_empty()


## 设置头像差分；null/空 → 隐藏头像窗并左移文本区补位（旁白/未登记差分）
func set_portrait(p_portrait: Texture2D) -> void:
	_portrait_rect.texture = p_portrait
	var has_face := p_portrait != null
	_portrait_frame.visible = has_face
	# 文本区随头像收放：有头像 x 从 112 起，无头像吃满文本带（规格 x∈[128,612] 的退化形态）
	_text_label.position.x = TEXT_RECT.position.x if has_face else 8.0
	_text_label.size.x = TEXT_RECT.size.x if has_face else TEXT_RECT.size.x + TEXT_RECT.position.x - 8.0


## 设置文本区内容（runner 每推进一批字调用一次）
func set_text(p_text: String) -> void:
	_text_label.text = p_text


## 逐字完成回调（runner 通知）：显示"▼ 可继续"提示
func on_text_completed() -> void:
	_continue_hint.visible = true


# ------------------------------------------------------------------
# 选项列表（GDD §4：最多 2 项，光标选择；边缘 4：必选其一）
# ------------------------------------------------------------------

## 打开选项列表：labels 为 1~2 项文案；光标归零、显示窗体
func open_choices(labels: Array) -> void:
	_choices_open = true
	_choice_cursor = 0
	for i: int in _choice_labels.size():
		var present: bool = i < labels.size()
		_choice_labels[i].visible = present
		if present:
			_choice_labels[i].text = "▶ " + String(labels[i])
	_choices_window.visible = true
	_continue_hint.visible = false


## 关闭选项窗（确认后由 runner 调用）
func close_choices() -> void:
	_close_choices()


## 选项输入处理：↑/↓ 移光标，interact 确认 → 发 choice_selected(idx)。
## 由 runner 在 WAITING_CHOICE 态调用（单输入通道原则，见头注释）；
## 取消/移动横轴等其他输入一律忽略（边缘 4：必选其一）。
func handle_choice_input(action: String) -> bool:
	if not _choices_open:
		return false
	var n := _visible_choice_count()
	if action == "move_up" or action == "move_down":
		if n > 1:
			_choice_cursor = (_choice_cursor + 1) % n   # ≤2 项：上下键同为循环切换
			_refresh_choice_cursor()
		return true   # 消费：移动键不穿透（即便只有 1 项也吞掉，防误翻页）
	if action == "interact":
		_choices_open = false
		choice_selected.emit(_choice_cursor)
		return true
	return false   # 其他动作不消费不响应


## 是否正在等选项（runner 观察用；状态正本在 runner，本布尔只是 UI 镜像）
func is_choices_open() -> bool:
	return _choices_open


func _visible_choice_count() -> int:
	var n := 0
	for l: Label in _choice_labels:
		if l.visible:
			n += 1
	return n


func _refresh_choice_cursor() -> void:
	for i: int in _choice_labels.size():
		if _choice_labels[i].visible:
			_choice_labels[i].text = ("▶ " if i == _choice_cursor else "　 ") + _choice_labels[i].text.substr(2)


func _close_choices() -> void:
	_choices_open = false
	_choices_window.visible = false
