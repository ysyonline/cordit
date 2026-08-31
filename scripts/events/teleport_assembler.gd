extends RefCounted
## teleport_assembler.gd —— E4-S6 传送触发器装配器（克隆 map_events.gd 模式）
##
## 【职责边界】纯装配、零行为：触发区几何/落位/目标全部来自 TeleportCatalog
##   （结构化数据正本）；本脚本把数据变成带协议的 Area2D 薄壳实体
##   （trigger_teleport.gd），行为分派在薄壳内。
##
## 【碰撞层位约定】（与 player.tscn 层位表一致）：
##   触发器 collision_layer = 0（自身不被检测）、collision_mask = 16（玩家实体）。
##   【E2-S2 回归修复】town 旧 4 门 mask=1 是玩家 layer=1 时代的配置，E2-S2
##   玩家改 layer=16 后 mask&layer=0 四门静默失效；本次目录驱动重建统一
##   mask=16，四门一并复活（回归根因与修复记录见 evidence/e4s6）。
##
## 【与 town 既有 4 门的关系】town.tscn 中 Door_Inn 等 4 个 Area2D 节点由
##   gen_town.py 生成、town_map.gd 直连行为（_routes 字典）。S6 起：
##   场景内 4 门保留（几何位置不变），行为改由本装配器目录驱动——
##   town_map.gd 的 _routes 分派退役，触发器统一挂 trigger_teleport 薄壳。
##   【实现取舍】不在 tscn 内换脚本引用（避免 gen 工具链二次维护），
##   而是装配器按目录"同位重建"触发器并移除旧 Area2D（详见 assemble）。

const TeleportCatalog := preload("res://scripts/events/teleport_catalog.gd")
const TriggerScript := preload("res://scripts/events/trigger_teleport.gd")


## 装配一张图的全部传送触发器。
## p_map_root：地图场景根（须含 Triggers 容器，五图均已有）；
## p_map_name：目录键；p_runner：对话运行器引用（无则 null）。
## 返回装配的触发器数组（测试对表用）。
static func assemble(p_map_root: Node, p_map_name: String, p_runner: Node = null) -> Array:
	var container: Node = p_map_root.get_node_or_null("Triggers")
	if container == null:
		push_warning("[TeleportAssembler] %s 无 Triggers 容器，跳过传送装配" % p_map_name)
		return []
	# town 旧 4 门是直连行为的 Area2D（无 trigger_teleport 脚本）：同位重建前移除，
	# 防双触发（旧直连 + 新薄壳同时对同一玩家生效）。判定依据 = 节点无脚本。
	for old in container.get_children():
		if old is Area2D and old.get_script() == null:
			old.queue_free()
	var built: Array = []
	for spec: Dictionary in TeleportCatalog.by_map(p_map_name):
		var trigger: Area2D = _build_trigger(spec, p_runner)
		container.add_child(trigger)
		built.append(trigger)
	print("[TeleportAssembler] %s 装配完成：传送触发器 %d 处" % [p_map_name, built.size()])
	return built


## 触发器实体：先设属性后入树（_ready 前属性就位，同 map_events 纪律）。
## 几何程序化构建：Area2D 位置 = 触发区中心，碰撞形状 = 尺寸全格。
static func _build_trigger(spec: Dictionary, p_runner: Node) -> Area2D:
	var trigger := Area2D.new()
	trigger.set_script(TriggerScript)
	trigger.name = TeleportCatalog.entity_name(String(spec["id"]))
	trigger.teleport_id = String(spec["id"])
	trigger.setup(p_runner)
	trigger.collision_layer = 0
	trigger.collision_mask = 16   # 玩家实体层（E2-S2 回归修复：旧值 1 已失效）
	var sz: Vector2i = spec["size"]
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(sz.x * 16.0, sz.y * 16.0)
	shape_node.shape = rect
	trigger.add_child(shape_node)
	trigger.position = TeleportCatalog.trigger_pixel_pos(spec)
	return trigger
