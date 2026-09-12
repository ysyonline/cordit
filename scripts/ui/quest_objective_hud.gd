extends Control
## quest_objective_hud.gd —— B-01 任务目标 HUD（M7 试玩反馈 B-01 引导缺位修复②）
##
## 【缺陷依据】R-1 外部试玩（m7-external-playtest-01.md §3 B-01）：玩家接取
##   委托后无任务目标指引——「没看见boss，不知道怎么触发」，走出小镇后
##   不知所措（story_phase=0 佐证从未接取）。headless 复现已证代码链零
##   断点（evidence/_story_chain_repro.log），本 HUD 补齐引导层的最后一块：
##   玩家任何时候抬头可见「当前该做什么」。
##
## 【行为】常驻左上角地图名下方（MapNameHud (8,8)~(8,28) 之下，y=32 起）。
##   监听两路信号驱动：
##   ① EventBus.story_phase_changed → 按 phase 换目标文案（见 OBJECTIVES 表）；
##   ② 装配面初始同步：_ready 直读 GameData.story_phase（带档启动/读档回图
##     等场景不重放 phase_changed 事件，须以现状落显）。
##   phase >= 3（终章后）隐藏——切片剧情收束，不再有"下一步"。
##
## 【文案口径】与剧情文本互证（story_p1_dispatch.json 委托原文"镇外那座
##   遗迹，一层有异常亮光"）：
##   phase 0 = 「查看告示板，接取委托」（未接取——R-1 玩家卡死点）
##   phase 1 = 「前往遗迹一层，调查异常亮光」
##   phase 2 = 「深入遗迹第三层，调查石棺」
##   phase >= 3 = 隐藏
##
## 【挂载】town_map.gd _assemble_map_name_hud 同款模式：UILayer 常驻跨图
##   复用（town 首装，遗迹图经既有实例续用；无 Main 结构测试树兜底挂本图）。
##   story_phase_changed 是全局事件，跨图自动续接，无需每图重装。
##
## 【布局】整树 mouse_filter = IGNORE（O-9 教训：HUD 类 UI 一律不吞输入）。
##   样式沿 menu_panel 五色板：羊皮纸半透明底 + 墨色 12px 文字；前置「◆」
##   目标符与地图名 HUD 视觉区分。

## phase → 目标文案映射（正本；phase>=3 无条目 = 隐藏语义由 has() 判定）
const OBJECTIVES: Dictionary = {
	0: "查看告示板，接取委托",
	1: "前往遗迹一层，调查异常亮光",
	2: "深入遗迹第三层，调查石棺",
}

## 五色板口径（map_name_hud 同源：墨色文字 + 羊皮纸底）
const C_INK := Color(0.290196, 0.231373, 0.321569)        # 4A3B52
const C_PARCHMENT := Color(0.909804, 0.862745, 0.752941, 0.85)  # E8DCC0 半透明

var _bg: ColorRect = null
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(8, 32)   # 地图名 HUD (8,8)+高20 之下留 4px 间距
	# 默认等值锚点（0,0,0,0）+ 直接设 size：不可用 PRESET_FULL_RECT——
	# 非等对锚下赋 size 会触发引擎告警（GUT 判 Unexpected Errors，
	# save_icon/m6t41 假红教训，同口径规避）。
	size = Vector2(220, 20)
	ensure_built()
	# 初始同步：装配时（town 首装/测试直挂）按当前 phase 落显——带档启动
	# 不重放 phase_changed，必须直读 GameData 现状
	_refresh(GameData.story_phase)
	EventBus.story_phase_changed.connect(_on_story_phase_changed)


## 构建静态子树（一次性，幂等；GUT 直驱入口）
func ensure_built() -> void:
	if _label != null:
		return
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = C_PARCHMENT
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(220, 20)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_label = Label.new()
	_label.name = "Objective"
	_label.position = Vector2(6, 2)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", C_INK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## phase 推进消费端：换目标文案（phase>=3 隐藏）。同值重放安全（幂等刷写）。
func _on_story_phase_changed(n: int) -> void:
	_refresh(n)


## 按 phase 刷新显示（文本 + 底条宽度 + 可见性一体刷新）
func _refresh(n: int) -> void:
	if not OBJECTIVES.has(n):
		visible = false   # phase>=3：终章后无目标，收摊
		return
	visible = true
	var text: String = "◆ " + String(OBJECTIVES[n])
	_label.text = text
	# 底条随文本宽度适配（12px 像素字体 ≈ 12px/汉字，左右各留 6px）
	var w: float = 12.0 * text.length() + 12.0
	_bg.size = Vector2(w, 20.0)


## 当前显示的目标文案（测试对表用；含「◆ 」前缀；隐藏时为上次文本）
func get_displayed_objective() -> String:
	return _label.text if _label != null else ""
