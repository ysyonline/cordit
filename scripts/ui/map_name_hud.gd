extends Control
## map_name_hud.gd —— M7-O10 地图名 HUD（用户 2026-09-12 拍板方案 A）
##
## 【需求依据】用户试玩反馈③"每一层最好显示当前地图名字"——遗迹三层结构
##   相似，无图名提示时玩家迷失深度感。
##
## 【行为】监听 EventBus.map_ready → 左上角淡入显示图名 → 驻留 2.4s → 淡出。
##   不常驻（640×360 小画面，常驻遮挡构图；打磨期可升级为常驻）。
##
## 【挂载】town_map.gd _assemble_menu 同款模式： UILayer 常驻跨图复用
##   （town 首装，遗迹图经既有实例续用；无 Main 结构测试树兜底挂本图随图生灭）。
##   图名来源 = map_ready 信号的 map_name 参数（与 AutosaveNotifier 同源口径），
##   显示名经 TeleportCatalog.display_name 映射（"ruins_f2"→"遗迹第二层"）。
##
## 【布局】左上角 (8,8) 起，12px 像素字体（project.godot custom_font 全局生效，
##   中文直接可渲染）；文字带半透明底条保证亮暗地图上均可读。
##   整棵 mouse_filter = IGNORE（不吞点击——O-9 教训：任何全屏/大面积
##   Control 默认 STOP 都会吞输入，此处从根节点到子节点全链 IGNORE）。

## 驻留时长（秒）：淡入 0.3 + 驻留 2.4 + 淡出 0.6
const FADE_IN: float = 0.3
const HOLD: float = 2.4
const FADE_OUT: float = 0.6

## 显示名映射（preload 常量——项目纪律：headless 不扫全局类注册表）
const TeleportCatalog := preload("res://scripts/events/teleport_catalog.gd")

## 五色板口径（menu_panel 同源：墨色文字 + 羊皮纸底）
const C_INK := Color(0.290196, 0.231373, 0.321569)        # 4A3B52
const C_PARCHMENT := Color(0.909804, 0.862745, 0.752941, 0.85)  # E8DCC0 半透明

var _label: Label = null
var _bg: ColorRect = null
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	# 注意：默认锚点（全相等）下直接赋 size 是安全的；若未来改 anchors 布局
	# 须走 set_deferred（引擎对"非等对锚+改 size"会在 _ready 后强改并告警，
	# test_m6t41 系 Unexpected Errors 假红教训）。
	size = Vector2(200, 24)
	visible = false
	modulate.a = 0.0
	ensure_built()
	# map_ready 是唯一入号（与 AutosaveNotifier.announce_ready 同帧同源；
	# 常驻节点跨图存活，连接一次终身生效——重复连接由 EventBus 语义规避，
	# 本节点在 town 首装后跨图复用，不会二次 _ready）
	EventBus.map_ready.connect(_on_map_ready)


## 构建静态子树（一次性，幂等；GUT 直驱入口）
func ensure_built() -> void:
	if _label != null:
		return
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = C_PARCHMENT
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(120, 20)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_label = Label.new()
	_label.name = "MapName"
	_label.position = Vector2(6, 2)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", C_INK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## map_ready 消费端：映射显示名 → 适配底条宽度 → 重放淡入驻留淡出动画。
## 同图重复广播（理论只有一次/图）安全：tween kill 后重放，视觉无害。
func _on_map_ready(map_name: String) -> void:
	var text: String = TeleportCatalog.display_name(map_name)
	_label.text = text
	# 底条随文本宽度适配（12px 像素字体 ≈ 12px/汉字，左右各留 6px）
	var w: float = 12.0 * text.length() + 12.0
	_bg.size = Vector2(w, 20.0)
	# 重放动画：旧 tween 在跑则先杀（跨图快速往返时防叠加）
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func() -> void: visible = false)


## 当前显示的图名（测试对表用；未显示时为上次图名）
func get_displayed_name() -> String:
	return _label.text if _label != null else ""
