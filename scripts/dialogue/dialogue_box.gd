extends Control
## dialogue_box.gd —— 对话框 UI 最小版（E1-S6）
##
## 【需求依据】EPIC-1 E1-S6："对话框最小版（名字栏 + 文本区 + 逐字显示 +
##   按键补完/翻页）"；对话 GDD §4：视口 640×360 内底部面板。
##   UI 布局规格（ui-layout-specs.md 对话框分镜）的完整版（头像窗/继续箭头/
##   选项列表）属后续 Story，本版只做名字栏 + 文本区 + 简洁面板。
##
## 【职责边界】纯展示层：只接受 set_speaker / set_text / open / close 喂数，
##   不读 JSON、不持有对话状态（状态在 DialogueRunner，A7 UI 分工）。
##   逐字计时也在 runner——本层不做 Timer，保证"改速率只动一处"。

## 名字栏（隐藏态 = 旁白，GDD §3.1：空串 speaker 无名字栏）
@onready var _speaker_label: Label = $Panel/Margin/VBox/SpeakerLabel
## 文本区（自动折行，GDD §3.1：≤60 汉字由渲染层折行）
@onready var _text_label: RichTextLabel = $Panel/Margin/VBox/TextLabel
## 继续提示（逐字完成后显示"▼"；完整版继续箭头后续 Story 精修）
@onready var _continue_hint: Label = $Panel/Margin/VBox/ContinueHint


func _ready() -> void:
	# 初始隐藏；visible 由 open/close 管理（对话期间其他 UI 交互不受影响）
	visible = false
	_continue_hint.visible = false


## 开框
func open() -> void:
	visible = true
	_continue_hint.visible = false


## 关框
func close() -> void:
	visible = false
	_continue_hint.visible = false


## 设置名字栏内容；空串 = 旁白 → 隐藏名字栏（GDD §3.1）
func set_speaker(p_speaker: String) -> void:
	_speaker_label.text = p_speaker
	_speaker_label.get_parent().visible = not p_speaker.is_empty()


## 设置文本区内容（runner 每推进一批字调用一次）
func set_text(p_text: String) -> void:
	_text_label.text = p_text


## 逐字完成回调（runner 通知）：显示"▼ 可继续"提示
func on_text_completed() -> void:
	_continue_hint.visible = true
