extends Control

## 战斗背景（E3-S5 · GDD §4.8「战场即场景」：地图截图模糊 + 暗角）
##
## 【定位】纯视图层。提供 set_screenshot(texture) 接口接收当前地图截图；
##   切片内无成套美术战斗背景，先用纯色底 + 暗角边框占位，待 E1/E4 地图
##   截图接入真实纹理。模糊由调用方在截图源头处理（或本层后续接 Shader），
##   本层只负责「铺图 + 暗角」两件事，保证"无穿帮"（GDD §4.8 验收）。
##
## 【约束】无 class_name（本项目 headless 跨脚本 class_name 解析陷阱；同
##   battle_ui / nine_slice_panel 一致模式：const 预载 + 实例类型推断）。

const VIEW_W := 640.0
const VIEW_H := 360.0

# 暗角边框厚度（像素）
const VIGNETTE := 48.0

var _screenshot: Texture2D = null
var _tex: TextureRect = null
var _base: ColorRect = null
var _vignette: Array[ColorRect] = []   # 上/下/左/右 四块半透明黑

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
	# 纯色底（截图未注入时的占位，防"黑屏穿帮"）
	_base = ColorRect.new()
	_base.name = "Base"
	_base.color = Color(0.07, 0.08, 0.11)
	_base.size = size
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)
	# 截图层（默认隐藏，待 set_screenshot 注入；STRETCH_COVER 填满视口）
	_tex = TextureRect.new()
	_tex.name = "Screenshot"
	_tex.size = size
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex.visible = false
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	# 暗角：四边半透明黑框（越靠边越暗，中心透明）
	_add_vignette("Vig_Top", 0.0, 0.0, VIEW_W, VIGNETTE)
	_add_vignette("Vig_Bottom", 0.0, VIEW_H - VIGNETTE, VIEW_W, VIGNETTE)
	_add_vignette("Vig_Left", 0.0, 0.0, VIGNETTE, VIEW_H)
	_add_vignette("Vig_Right", VIEW_W - VIGNETTE, 0.0, VIGNETTE, VIEW_H)


func _add_vignette(p_name: String, x: float, y: float, w: float, h: float) -> void:
	var r := ColorRect.new()
	r.name = p_name
	r.color = Color(0.0, 0.0, 0.0, 0.55)
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	_vignette.append(r)


## 注入当前地图截图（真实纹理由 E4 探索侧提供；占位阶段传 null 走纯色）
func set_screenshot(tex: Texture2D) -> void:
	_screenshot = tex
	if _tex != null:
		_tex.texture = tex
		_tex.visible = tex != null


# =============== 查询接口（供测试 / 验收断言） ===============

func has_screenshot() -> bool:
	return _screenshot != null


func get_screenshot() -> Texture2D:
	return _screenshot


func vignette_count() -> int:
	return _vignette.size()


func get_base_color() -> Color:
	return _base.color
