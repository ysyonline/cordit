extends Control

## 战斗转场（E3-S5 · 遇敌进/出战黑屏淡入淡出）
##
## 【定位】纯视图层。遇敌触发：play_intro() 从全黑淡出到清（0.2s）；
##   胜利/失败收尾时 play_outro() 由清淡入到全黑。置于 BattleUI 最顶层，
##   保证转场期间遮挡全部 HUD 与战斗内容（无穿帮）。
##
## 【约束】无 class_name（本项目 headless 跨脚本 class_name 解析陷阱）。

const VIEW_W := 640.0
const VIEW_H := 360.0

# 进战黑屏时长（秒）
const INTRO_TIME := 0.2
# 出战黑屏时长（秒）
const OUTRO_TIME := 0.3

var _black: ColorRect = null
var black_alpha := 1.0        # 起始全黑（进战首帧）
var _playing := false
var _mode := ""               # "intro" / "outro" / ""

var _built: bool = false


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


func _build() -> void:
	_black = ColorRect.new()
	_black.name = "TransitionBlack"
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.size = size
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	black_alpha = 1.0
	_playing = true
	_mode = "intro"


func _process(delta: float) -> void:
	if not _playing:
		return
	if _mode == "intro":
		black_alpha = maxf(0.0, black_alpha - delta / INTRO_TIME)
	elif _mode == "outro":
		black_alpha = mini(1.0, black_alpha + delta / OUTRO_TIME)
	if _black != null:
		_black.color.a = black_alpha
	if _mode == "intro" and black_alpha <= 0.0:
		_playing = false
		_mode = ""
	elif _mode == "outro" and black_alpha >= 1.0:
		_playing = false
		_mode = ""


# =============== 转场控制 ===============

## 进战：从黑淡出到清（0.2s）
func play_intro() -> void:
	_playing = true
	_mode = "intro"
	black_alpha = 1.0
	if _black != null:
		_black.color.a = 1.0


## 出战（结算收尾）：从清淡入到全黑（0.3s）
func play_outro() -> void:
	_playing = true
	_mode = "outro"
	black_alpha = 0.0
	if _black != null:
		_black.color.a = 0.0


func is_playing() -> bool:
	return _playing


func get_black_alpha() -> float:
	return black_alpha


func get_mode() -> String:
	return _mode
