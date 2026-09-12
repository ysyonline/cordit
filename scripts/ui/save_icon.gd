extends Control
## save_icon.gd —— 存档反馈条（E4-S6 闪现图标 → M7-O11 文字反馈升级，
## 用户 2026-09-12 拍板④A"存档后给列表/索引反馈"）
##
## 【升级自】E4-S6 最小版（右下角 12×12 色块闪 0.5s）——用户试玩反馈
##   "存档后没有给一个（存到哪的）反馈"。单存档槽架构下"存到哪"= 哪张图
##   （save.json 的 map 字段），故反馈文案 = "已存档 · <显示名>"；写盘失败
##   = "存档失败"（警示红，旧档保留语义见 SaveManager 原子写）。
##
## 【协议兼容】flash(p_ok) 入口签名不变（autosave_notifier 既有调用零改动）；
##   新增 flash_map(p_ok, map_name) 带图名变体，两入口最终汇合 _run()。
##   挂载/自毁协议不变：由调用方程序化挂地图根，动画毕自毁（0.5s→1.6s，
##   文字可读时长加长）。
##
## 【布局】右下角文字条：半透明羊皮纸底 + 墨色 12px 文字（menu_panel 五色板
##   同源），锚定父容器右下（地图视口 640×360，ADR-4）。整树 mouse_filter =
##   IGNORE（O-9 教训：反馈类 UI 一律不吞输入）。
##
## 【美术升级位】正式美术（存档图标帧动画）归打磨期替换：只换本节点视觉
##   子树，flash/flash_map 协议不变。

## 显示时长（秒）：0.7s 驻留 + 0.4s 淡出 + 0.5s 余量（文字可读性 > 方块版 0.5s）
const FLASH_DURATION: float = 1.6

## 成功/失败色（成功=暖白底墨字；失败=警示红底白字——色差兜底，失败态目前仅写盘异常可见）
const COLOR_BG_OK := Color(0.909804, 0.862745, 0.752941, 0.88)   # E8DCC0 半透明
const COLOR_BG_FAIL := Color(0.698039, 0.192157, 0.149020, 0.92) # B23126 半透明
const COLOR_TEXT_OK := Color(0.290196, 0.231373, 0.321569)       # 4A3B52 墨
const COLOR_TEXT_FAIL := Color(1.0, 0.97, 0.9)                   # 暖白

var _bg: ColorRect = null
var _label: Label = null

## 显示名映射（preload 常量——项目纪律：headless 不扫全局类注册表）
const TeleportCatalog := preload("res://scripts/events/teleport_catalog.gd")


func _ready() -> void:
	# 右下角锚定：底条 132×20，从父容器右下角向内收 8px
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -140.0
	offset_top = -28.0
	offset_right = -8.0
	offset_bottom = -8.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = ColorRect.new()
	_bg.name = "Bg"
	# 默认等值锚点（0,0,0,0）+ 直接设 size：不可用 PRESET_FULL_RECT——
	# 非等对锚下赋 size 会触发引擎告警（GUT 判 Unexpected Errors，
	# test_m6t41/m6t42 八条假红根因）。
	_bg.position = Vector2.ZERO
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_label = Label.new()
	_label.name = "Text"
	_label.position = Vector2(6, 3)
	_label.add_theme_font_size_override("font_size", 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## 闪现入口（E4-S6 兼容签名）：不带图名的旧调用方 → 纯"已存档"文案
func flash(p_ok: bool = true) -> void:
	_run(p_ok, "")


## 带图名闪现（M7-O11 主入口）：文案 = "已存档 · <显示名>"
func flash_map(p_ok: bool, map_name: String) -> void:
	_run(p_ok, map_name)


## 动画主体：着色 → 显示 → 淡出 → 自毁
func _run(p_ok: bool, map_name: String) -> void:
	_bg.color = COLOR_BG_OK if p_ok else COLOR_BG_FAIL
	_label.add_theme_color_override("font_color",
			COLOR_TEXT_OK if p_ok else COLOR_TEXT_FAIL)
	if p_ok and not map_name.is_empty():
		_label.text = "已存档 · %s" % TeleportCatalog.display_name(map_name)
	elif p_ok:
		_label.text = "已存档"
	else:
		_label.text = "存档失败"
	# 底条宽度随文案适配（12px 像素字体 ≈ 12px/汉字；失败文案短，同式适配）
	var w: float = 12.0 * _label.text.length() + 14.0
	_bg.size = Vector2(w, 20.0)
	modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(FLASH_DURATION * 0.75)
	tw.tween_property(self, "modulate:a", 0.0, FLASH_DURATION * 0.25)
	tw.tween_callback(queue_free)
