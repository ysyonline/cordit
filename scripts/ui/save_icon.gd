extends Control
## save_icon.gd —— E4-S6 存档闪现图标（探索 GDD §4：自动存档时右下角闪现 0.5s）
##
## 【最小实现】ColorRect + tween 透明度脉冲；正式美术（磁盘/软盘图标帧动画）
##   归 E6 打磨期替换（只换本节点的视觉子树，flash 协议不变）。
## 【挂载】由 autosave_notifier 程序化挂到地图根；0.6s 后自毁（0.5s 显示
##   + 0.1s 余量），无跨帧状态。
## 【布局】右下角 12×12 方块，锚定父容器右下角（地图视口 640×360，ADR-4）。

## 显示时长（秒）——GDD §4 钉定 0.5s
const FLASH_DURATION: float = 0.5

## 成功/失败色（成功=暖白，失败=警示红；失败态目前仅日志可见，色差兜底）
const COLOR_OK := Color(1.0, 0.97, 0.9)
const COLOR_FAIL := Color(0.9, 0.25, 0.2)


func _ready() -> void:
	# 右下角锚定：offset 从父容器右下角向内收 8px
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -20.0
	offset_top = -20.0
	offset_right = -8.0
	offset_bottom = -8.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ColorRect.new()
	rect.name = "Glyph"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


## 闪现入口：显示 → 淡出 → 自毁。p_ok=false 时用警示色（存档失败的可见信号）。
func flash(p_ok: bool = true) -> void:
	var glyph: ColorRect = get_node("Glyph") as ColorRect
	glyph.color = COLOR_OK if p_ok else COLOR_FAIL
	modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(FLASH_DURATION * 0.7)
	tw.tween_property(self, "modulate:a", 0.0, FLASH_DURATION * 0.3)
	tw.tween_callback(queue_free)
