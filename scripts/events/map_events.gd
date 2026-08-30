extends Node
## map_events.gd —— E4-S5 点位装配器：读 PointCatalog → 实体化 27 个内容点位
##
## 【职责边界】（A7 延伸）纯装配、零内容：坐标/道具/文案 id 全部来自
##   PointCatalog（结构化数据正本，E5 回迁 JSON 后由加载器替换本层）；
##   本脚本不理解"哪个箱子给什么"——只把数据变成带协议的实体。
##
## 【为什么装配方独立成类】五张地图根脚本（town/road/f1/f2/f3）都要长出
##   同一段装配逻辑；收口在一处 static 入口，地图侧一行调用（E4-S2/S3
##   "克隆简版结构"的地图件不做复制粘贴扩散）。
##
## 【与既有锚点的关系】road/f1/f2/f3 的 21 个 Marker2D 锚点（E4-S2/S3
##   制作校验对表的验收物）原样保留、不删不改：锚点是"点位在哪"的标记，
##   本装配器按【目录坐标】摆实体，测试侧对表断言"实体与锚点同位"，
##   两套数据互为校验（防目录改坐标忘改场景、或反向漂移）。
##   town 的 6 个调查点无既有锚点（E1-S5 制作单未含），实体即首次落位。
##
## 【时序】由地图根脚本 _ready 尾部调用（player/interaction_controller
##   均已在树）；测试树可在任意宿主节点上手动调用（见 test_e4s5.gd）。

const PointCatalog := preload("res://scripts/events/point_catalog.gd")
const ChestScript := preload("res://scripts/events/chest.gd")
const InvestigateScript := preload("res://scripts/events/investigate_point.gd")


## 装配一张图的全部点位（宝箱 + 调查点）。
## p_map_root：地图场景根（含 YSorted 结构）；p_map_name：目录键
## （PointCatalog.SPAWNS/CHESTS/INVESTIGATES 的 map 字段值）。
## 返回 { "chests": Array[Node], "investigates": Array[Node] }（测试对表用）。
static func assemble(p_map_root: Node, p_map_name: String) -> Dictionary:
	var ysorted: Node = p_map_root.get_node("YSorted")
	var chests: Array = []
	var investigates: Array = []
	for spec: Dictionary in PointCatalog.CHESTS:
		if String(spec["map"]) != p_map_name:
			continue
		var chest: StaticBody2D = _build_chest(spec)
		_place(ysorted, chest, spec["tile"])
		chests.append(chest)
	for spec: Dictionary in PointCatalog.INVESTIGATES:
		if String(spec["map"]) != p_map_name:
			continue
		var inv: StaticBody2D = _build_investigate(spec)
		_place(ysorted, inv, spec["tile"])
		investigates.append(inv)
	print("[MapEvents] %s 装配完成：宝箱 %d + 调查 %d" % [
			p_map_name, chests.size(), investigates.size()])
	return {"chests": chests, "investigates": investigates}


## 宝箱实体：先设属性后入树（_ready 前属性就位，同 test_e4s4 spawn 纪律）。
## 【几何装配】本模板无 .tscn 场景件（与 npc.tscn 不同），碰撞形状在此程序化
##   构建：根 StaticBody2D layer=2（交互物层，被玩家 InteractRay 命中）
##   mask=0；InteractShape 16x16 @ (0,-7)（与 npc.tscn InteractBody 同规格）。
##   【GUT 实测教训】漏建形状时射线会命中宝箱身后 tilemap 的层1墙体——
##   协议链静默断裂且无报错，只能靠端到端用例兜住（见证据档）。
static func _build_chest(spec: Dictionary) -> StaticBody2D:
	var chest := StaticBody2D.new()
	chest.set_script(ChestScript)
	chest.name = PointCatalog.chest_entity_name(String(spec["id"]))
	chest.chest_id = String(spec["id"])
	chest.event_id = String(spec["id"])
	chest.item_id = String(spec["item_id"])
	chest.item_count = int(spec["count"])
	chest.dialogue_id = chest_dialogue_id(String(spec["id"]))
	chest.open_sfx_path = "res://assets/audio/sfx/chest_open.ogg"   # E6 音频钩子
	chest.collision_layer = 2
	chest.collision_mask = 0
	_add_interact_shape(chest, Vector2(0, -7))
	chest.position = _pixel_center(spec["tile"])
	return chest


## 调查点实体（无状态：id + dialogue id 两个属性即全部数据；几何同宝箱规格）
static func _build_investigate(spec: Dictionary) -> StaticBody2D:
	var inv := StaticBody2D.new()
	inv.set_script(InvestigateScript)
	inv.name = PointCatalog.inv_entity_name(String(spec["id"]))
	inv.inv_id = String(spec["id"])
	inv.event_id = String(spec["id"])
	inv.dialogue_id = "flavor_" + String(spec["id"])   # = flavor 文件名（runner 契约）
	inv.collision_layer = 2
	inv.collision_mask = 0
	_add_interact_shape(inv, Vector2(0, -6))
	inv.position = _pixel_center(spec["tile"])
	return inv


## 挂交互判定形状（16x16 矩形，层2 专用；不挂层1——宝箱/调查点不挡路）
static func _add_interact_shape(body: StaticBody2D, offset: Vector2) -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.name = "InteractShape"
	shape_node.position = offset
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape_node.shape = rect
	body.add_child(shape_node)


## tile 坐标 → 格中心像素（全项目锚点口径 tx*16+8，同 verify_road.py 对表式）
static func _pixel_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * 16 + 8, tile.y * 16 + 8)


## 入树：无视觉层占位实体（锚点已带美术），几何即全部
static func _place(ysorted: Node, entity: Node, _tile: Vector2i) -> void:
	ysorted.add_child(entity)


## 宝箱提示对话 id 命名约定：chest_road_01 -> dlg_chest_road_01
static func chest_dialogue_id(id: String) -> String:
	return "dlg_" + id
