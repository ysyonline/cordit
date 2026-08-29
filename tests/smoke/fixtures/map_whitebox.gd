extends Node2D
## map_whitebox —— 白盒测试图共享根脚本（E1-S3 验证场景，不进正式构建路径）
##
## 【职责】：
##   ① 自报家门：_ready 打印 [WhiteBoxMap] 一行（地图名 / 显示色），人眼与
##      日志双通道确认 A→B→A 切换真实发生（SMK-08 验收点）；
##   ② 发 map_ready：装载完成后向 EventBus 报告"地图装载完成"——
##      信号归属裁决：map_ready 只能由地图场景自己发射（"我是谁、何时算装载
##      完成"只有地图自己知道），SceneRouter 不代发、不监听（A3/A7 一致性，
##      详见 autoload/scene_router.gd 头注释）。
##
## 【用法】：每张白盒图只配一个 map_id（Inspector 可改或 tscn 内覆盖），
##   画面 = 纯色 ColorRect + 地图名 Label（架构 C2 第 2 周练习同款做法）。
##
## 【边界】：不实现任何玩法；不引用其他场景；切图一律经 SceneRouter。

## 地图标识（也作为 map_ready 参数与日志标识；图 A / 图 B 各覆盖一个值）
@export var map_id: String = "map_a"

## 本图显示色（tscn 内按图覆盖，用于人眼区分切换效果）
@export var display_color: Color = Color(0.25, 0.45, 0.30)


func _ready() -> void:
	var rect: ColorRect = get_node_or_null("Backdrop") as ColorRect
	if rect != null:
		rect.color = display_color
	var label: Label = get_node_or_null("MapLabel") as Label
	if label != null:
		label.text = "白盒图 %s" % map_id
	print("[WhiteBoxMap] 装载完成：", map_id, "（显示色 ", display_color, "）")
	EventBus.map_ready.emit(map_id)
