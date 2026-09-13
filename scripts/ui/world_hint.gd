extends RefCounted
## world_hint.gd —— 世界空间「❗Z」交互提示标签工厂（M8-A②）
##
## 【需求依据】M8-A②：NPC 交互引导缺位——玩家须站到 NPC 面前 1 格按 Z 且无任何
##   视觉反馈，不知哪里/什么时候可交互。本工厂统一产出既有的「❗Z」脉冲标签
##   （逐字教会交互键），供 NPC 头顶交互提示调用。
##
## 【复用既有手法（不新造样式）】视觉三件套与 town_map._attach_billboard_hint
##   (B-01 告示板「!」) / ruins_f3_map._attach_interact_hint (O-12 Boss 锚点)
##   完全一致——玩家已实证该样式可发现：
##     · 文案「❗Z」；字号 12；颜色 D9A94E 金 (0.850980,0.662745,0.305882)；
##     · mouse_filter = IGNORE（不吃点击）；0.6s 周期透明度 0.55↔1.0 循环脉冲
##       （引擎时隙 tween，不自建 Timer）。
##   本工厂把这套手法 + 层位铁律固化为一处。三处「❗Z」提示（B-01 告示板 /
##   O-12 Boss 锚点 / M8-A② NPC 头顶）现均经本工厂产出。
##
## 【层位铁律（本工厂强制）】提示必须恒浮于建筑层（WallsObjects，M8-A③ 后已在
##   YSorted 内，z=0）与树冠层（Above，根直挂，z=+10）之上，否则会被建筑/树冠
##   盖住（M8-A③ 已修 y-sort；本提示不能因此被掩）。故强制 z_index =
##   HINT_Z_INDEX(12) > 10：z_index 在 canvas 内全局排序，无论调用方把提示挂在
##   哪棵子树，凡 z_index 更高者后绘于其上——由 z_index 单独保证可见，不依赖树序。
##   （因此调用方**无需**借 current_scene 求"渲染序最上"，见下。）
##
## 【挂载责任在调用方，且必须挂"随宿主生灭"的节点】本工厂只造节点 + 样式 +
##   脉冲，不决定挂谁。调用方必须保证提示随宿主**生灭**。
##   ⚠️ 反例（M8-A② rev2 实机命中的缺陷②）：告示板/Boss 提示原挂
##   get_tree().current_scene(Main)（跨图常驻），离开地图后标签仍悬在 Main 下
##   继续渲染 → 出现"没 NPC 的地方也有 ❗"且反复进图叠影。**正解：挂地图根
##   （self）或 NPC 自身**——随图销毁；可见性/层级由 z_index 保证，无需常驻宿主。

## 金色（D9A94E）——与既有两处提示正本同值
const GOLD: Color = Color(0.850980, 0.662745, 0.305882)

## 「❗Z」标签 z_index：> Above(z=+10)，保证恒浮于建筑层/树冠之上
const HINT_Z_INDEX: int = 12

## 脉冲谷值透明度与半周期时长（秒）——与既有两处提示同值
const PULSE_DIM: float = 0.55
const PULSE_HALF_PERIOD: float = 0.6


## 造一枚「❗Z」提示标签并挂到 p_host 的 p_position（宿主本地坐标）。
## 返回标签实例供调用方控显隐（默认可见；如需"入范围才显"，挂后自行
## 置 visible=false 并由业务逐帧翻转）。p_host 须为已入树节点（脉冲 tween
## 需节点在树内）；未入树时标签仍建立、仅跳过脉冲（headless/装配面无碍）。
## p_name：节点名（默认 InteractHint；告示板处传 "BillboardHint" 保持既有命名兼容）。
static func attach(p_host: Node, p_position: Vector2, p_text: String = "❗Z",
		p_name: String = "InteractHint") -> Label:
	var hint := Label.new()
	hint.name = p_name
	hint.text = p_text
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", GOLD)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = HINT_Z_INDEX
	hint.position = p_position
	p_host.add_child(hint)
	_start_pulse(hint)
	return hint


## 呼吸脉冲：0.6s 周期透明度 0.55↔1.0 无限往返（吸引注视但不吵）。
## 未入树或引擎未给 Tween 时静默跳过（不报错、不泄漏）。
static func _start_pulse(p_hint: Label) -> void:
	if not p_hint.is_inside_tree():
		return
	var tw: Tween = p_hint.create_tween()
	if tw == null:
		return
	tw.set_loops()
	tw.tween_property(p_hint, "modulate:a", PULSE_DIM, PULSE_HALF_PERIOD)
	tw.tween_property(p_hint, "modulate:a", 1.0, PULSE_HALF_PERIOD)
