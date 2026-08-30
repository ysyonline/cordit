extends Control

## 受击打击反馈（E3-S5 · GDD §4.6 克制橙字 + §3.3 跨战斗弱点记忆写入）
##
## 【定位】纯视图层。监听 BattleCommand 的 damage / weakness 事件，在浮层上：
##   ① 受击闪白（全屏白幕，0.1s 淡出）——“被打到了”的体感锚点；
##   ② 克制：橙字放大 1.3 倍 + 弹字"弱点！"——§3.3 首见弱点三步呈现之弹字；
##   ③ 弱点命中时把 element 写入 GameData.discovered_weakness_set——跨战斗记忆。
##
## 【约束】无 class_name（本项目 headless 跨脚本 class_name 解析陷阱）。

const VIEW_W := 640.0
const VIEW_H := 360.0

# 闪白时长（秒）
const FLASH_TIME := 0.1

# 受击闪白层
var _flash: ColorRect = null
var flash_alpha := 0.0

# 弱点弹字层
var _popup_layer: Control = null

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
	# 闪白幕：默认透明、置顶、忽略鼠标
	_flash = ColorRect.new()
	_flash.name = "HitFlash"
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.size = size
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	# 弹字层
	_popup_layer = Control.new()
	_popup_layer.name = "WeakPopupLayer"
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup_layer)


func _process(delta: float) -> void:
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - delta / FLASH_TIME)
		if _flash != null:
			_flash.color.a = flash_alpha


# =============== 受击闪白 ===============

## 立即拉满 alpha（_process 内按 FLASH_TIME 淡出）
func trigger_flash() -> void:
	flash_alpha = 1.0
	if _flash != null:
		_flash.color.a = 1.0


func get_flash_alpha() -> float:
	return flash_alpha


# =============== 克制弹字（§3.3 首见弱点） ===============

## 橙字放大 1.3 倍弹"弱点！"；pos 为屏幕坐标（由 BattleUI 计算目标位置传入）
func spawn_weak_popup(pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.name = "WeakPopup"
	lbl.text = "弱点！"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.60, 0.10))
	lbl.scale = Vector2(1.3, 1.3)
	lbl.position = pos
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(lbl)


func get_popup_count() -> int:
	return _popup_layer.get_child_count()


func get_popup_text(idx: int) -> String:
	var c: Label = _popup_layer.get_child(idx) as Label
	return c.text


# =============== 跨战斗弱点记忆写入（§3.3） ===============

## element 非空且 GameData 可用时，写入 discovered_weakness_set（查重）
## GameData 为 autoload 全局单例（同 test_sanity 直接引用，headless 可用）
func record_weakness(element: String) -> void:
	if element.is_empty():
		return
	if not GameData.discovered_weakness_set.has(element):
		GameData.discovered_weakness_set.append(element)
