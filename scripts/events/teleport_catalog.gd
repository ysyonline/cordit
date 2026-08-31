extends RefCounted
## teleport_catalog.gd —— E4-S6 全部 12 处传送结构化数据表（传送数据正本）
##
## 【数据正本模式】沿 E4-S5 拍板项④：EPIC-5 JSON 事件加载器未就绪 → 本 Story
##   硬编码触发器先行，但 12 处传送数据（id/图/触发区/落位）必须结构化落盘，
##   保证 E5 回迁时数据可平移：本表即数据源，data/json/events/teleports.json
##   为同构 JSON 镜像（GUT 锁死同构；E5 加载器读 JSON 后本表降级为校验锚或
##   直接删除）。
##
## 【坐标口径】触发区与落位全部用 tile 坐标（Vector2i / 半格用 .5），装配时
##   转像素 tile*16+8（格中心，与 PointCatalog/_pixel_center 同口径）。
##   落位原则（E1-S5 门垫同款）：落位恒在触发区之外一格，防原地弹回循环。
##
## 【12 处构成】town 室内 4（同图位置传送：Door_Inn/Door_HouseA/Inn_Exit/
##   HouseA_Exit）+ 跨图 8（town→road、road→town、road→f1、f1→road、
##   f1→f2、f2→f1、f2→f3、f3→f2）。
##   坐标来源：gen_town.py / gen_road.py / gen_ruins.py 的门位 + 各图既有
##   spawn 落位（@export 值）。
##
## 【同图室内传送存档裁定】（E4-S6 裁决权，evidence 记录理由）：
##   跨图传送 → 触发自动存档；同图室内传送 → 不存档。
##   理由：存档语义 = "安全点"（失败读档恢复位）。室内无遇敌风险（town 零
##   敌人、室内又是 town 安全区内部），进出客栈/民居不构成进度推进；若同图
##   也存，玩家在室内开门的瞬间会覆盖"站在门外主图"的存档点，语义反而劣化。
##   跨图才存的另一依据：进图自动存档的本意是"失败读档回到该图入口"（战斗
##   GDD §3.5），室内无战斗入口可言。

## 跨图传送时是否触发自动存档（TriggerTeleport 消费；true=存）
const CROSS_MAP_SAVE: bool = true

## ------------------------------------------------------------------
## 触发区定义（12 处）
## 字段：
##   id        全局唯一传送 id（= JSON 镜像主键 / 实体节点名后缀）
##   map       触发区所在图（PointCatalog.SPAWNS 同款图名键）
##   tile      触发区左上角 tile（Vector2i）
##   size      触发区格数（Vector2i，1×1 或 2×1；转像素 = *16）
##   kind      "same_map"（同图位置传送）/ "cross_map"（跨图切换）
##   target    同图传送落位 tile（仅 kind=same_map 时消费；tile 中心像素）
##   to_map    目标图名（仅 kind=cross_map 时消费）
##   to_spawn  目标图落位 tile（仅 kind=cross_map；可为半格 .5 = 门中缝）
## ------------------------------------------------------------------
const TELEPORTS: Array[Dictionary] = [
	# ======== town 室内 4（同图；坐标 = town.tscn 既有 4 个 Area2D 原样迁移，
	#          落位 = town_map.gd 原 @export 四落位）========
	{
		"id": "tp_town_door_inn", "map": "town",
		"tile": Vector2i(29, 18), "size": Vector2i(1, 1),
		"kind": "same_map", "target": Vector2(85, 17),
		"to_map": "", "to_spawn": Vector2.ZERO,
	},   # Door_Inn：客栈门 → 室内A (85,17) 格中心落位、室内限区
	{
		"id": "tp_town_door_house_a", "map": "town",
		"tile": Vector2i(12, 18), "size": Vector2i(1, 1),
		"kind": "same_map", "target": Vector2(85, 29),
		"to_map": "", "to_spawn": Vector2.ZERO,
	},   # Door_HouseA：民居门 → 室内B (85,29) 格中心落位、室内B限区
	{
		"id": "tp_town_inn_exit", "map": "town",
		"tile": Vector2i(85, 18), "size": Vector2i(1, 1),
		"kind": "same_map", "target": Vector2(29, 19),
		"to_map": "", "to_spawn": Vector2.ZERO,
	},   # Inn_Exit：室内A出口（(85,18) 与旧 tscn 节点同位）→ 主图 (29,19) 格中心、主限区
	{
		"id": "tp_town_house_a_exit", "map": "town",
		"tile": Vector2i(85, 30), "size": Vector2i(1, 1),
		"kind": "same_map", "target": Vector2(12, 19),
		"to_map": "", "to_spawn": Vector2.ZERO,
	},   # HouseA_Exit：室内B出口（(85,30) 与旧 tscn 节点同位）→ 主图 (12,19) 格中心、主限区

	# ======== 跨图 8（门位 = gen 脚本开口；落位在触发区之外一格防弹回）========
	{
		"id": "tp_town_to_road", "map": "town",
		"tile": Vector2i(12, 47), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "road", "to_spawn": Vector2(23.5, 3.5),
	},   # town 南门 (12-13,47) → road 北门南下；落位 road (23.5,3.5)=既有 from_town 参考格
	{
		"id": "tp_road_to_town", "map": "road",
		"tile": Vector2i(23, 0), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "town", "to_spawn": Vector2(12.5, 45.5),
	},   # road 北门 (23-24,0) → town 南门内一格 (12-13,45 之间中缝)；栅栏已拆（R1），45 行安全
	{
		"id": "tp_road_to_f1", "map": "road",
		"tile": Vector2i(23, 63), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "ruins_f1", "to_spawn": Vector2(27.5, 3),
	},   # road 南门 (23-24,63) → f1 南门南下；落位 f1 (27.5,3)=pos_from_road 同位（verify_ruins 锚定）
	{
		"id": "tp_f1_to_road", "map": "ruins_f1",
		"tile": Vector2i(27, 0), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "road", "to_spawn": Vector2(23.5, 61.5),
	},   # f1 北口 (27-28,0) → road 南门内（H6 路面 (23-24,61) 中缝）；落位距 y=63 触发区 2 行防弹回
	{
		"id": "tp_f1_to_f2", "map": "ruins_f1",
		"tile": Vector2i(27, 43), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "ruins_f2", "to_spawn": Vector2(23.5, 2),
	},   # f1 北口楼梯厅 (27-28,43) → f2 南门南下；落位 f2 (23.5,2)=pos_from_f1 同位（verify_ruins 锚定）
	{
		"id": "tp_f2_to_f1", "map": "ruins_f2",
		"tile": Vector2i(23, 0), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "ruins_f1", "to_spawn": Vector2(27.5, 41.5),
	},   # f2 北口 (23-24,0) → f1 楼梯走道 (27-28,41 中缝)；落位距 y=43 北口触发区 2 行防弹回
	{
		"id": "tp_f2_to_f3", "map": "ruins_f2",
		"tile": Vector2i(23, 47), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "ruins_f3", "to_spawn": Vector2(19.5, 2),
	},   # f2 北口楼梯厅 (23-24,47) → f3 南门南下；落位 f3 (19.5,2)=pos_from_f2 同位（verify_ruins 锚定）
	{
		"id": "tp_f3_to_f2", "map": "ruins_f3",
		"tile": Vector2i(19, 0), "size": Vector2i(2, 1),
		"kind": "cross_map", "target": Vector2.ZERO,
		"to_map": "ruins_f2", "to_spawn": Vector2(23.5, 45.5),
	},   # f3 南门 (19-20,0)（双用途：f2→f3 的入口门 + 返程触发区）；返程落位 f2 (23.5,45.5)=北口楼梯走道中缝，距 y=47 触发区 2 行防弹回
	]     # ↑ f3 无北口（Boss 门封死构图）：f3→f2 返程走南门，触发区与入口同位复用

## ------------------------------------------------------------------
## 各图标准入口参考表（文档用途：首次进入该图的典型落位）。
## 【注意】road/f1/f2 是双入口图（南北门），本表只记"首入"标准位；
##   自动存档的快照坐标不查此表——地图 _ready 时玩家已落位到实际入口，
##   存档恒取玩家当前实际位置（GDD §3.4"站在新图入口"）。
## 值 = tile 坐标（可含 .5 半格），像素 = *16+8
## ------------------------------------------------------------------
const ENTRY_SPAWNS: Dictionary = {
	"town": Vector2(12.5, 45.5),      # 南门内（road→town）
	"road": Vector2(23.5, 3.5),       # 北门南下（town→road）
	"ruins_f1": Vector2(27.5, 3),     # 南门南下（road→f1）= pos_from_road
	"ruins_f2": Vector2(23.5, 2),     # 南门南下首入（f1→f2）= pos_from_f1；返程入口见 tp_f3_to_f2.to_spawn
	"ruins_f3": Vector2(19.5, 2),     # 南门南下（f2→f3）= pos_from_f2
}

## 五图场景路径（跨图传送目标；调用方 SceneRouter.change_scene 消费）
const MAP_SCENE_PATHS: Dictionary = {
	"town": "res://scenes/maps/town.tscn",
	"road": "res://scenes/maps/road.tscn",
	"ruins_f1": "res://scenes/maps/ruins_f1.tscn",
	"ruins_f2": "res://scenes/maps/ruins_f2.tscn",
	"ruins_f3": "res://scenes/maps/ruins_f3.tscn",
}

## 室内限区（同图传送落位后的相机限区；town_map.gd @export 三组正本镜像）。
## 同图传送 kind=same_map 时按落位所在区域查此表应用限区（door_inn/house_a
## 室内、exit 回主图）。键 = 传送 id。
const SAME_MAP_LIMITS: Dictionary = {
	"tp_town_door_inn": Rect2i(1056, 0, 640, 360),
	"tp_town_door_house_a": Rect2i(1056, 188, 640, 360),
	"tp_town_inn_exit": Rect2i(0, 0, 1024, 768),
	"tp_town_house_a_exit": Rect2i(0, 0, 1024, 768),
}


## tile 坐标（可含 .5）→ 格中心像素（tx*16+8 口径；.5 半格 = 两格中缝 8px 整倍）
static func tile_to_pixel(t: Vector2) -> Vector2:
	return Vector2(t.x * 16.0 + 8.0, t.y * 16.0 + 8.0)


## 触发区像素位（左上角）：tile * 16（区域左上角不需要 +8 偏移——Area2D 的
## 碰撞形状以区域几何中心为原点，见装配器 _build_shape）
static func trigger_pixel_pos(spec: Dictionary) -> Vector2:
	var tl: Vector2i = spec["tile"]
	var sz: Vector2i = spec["size"]
	return Vector2(tl.x * 16.0 + sz.x * 8.0, tl.y * 16.0 + sz.y * 8.0)


## 按 id 查传送定义（未命中返回空字典）
static func by_id(id: String) -> Dictionary:
	for spec: Dictionary in TELEPORTS:
		if String(spec["id"]) == id:
			return spec
	return {}


## 某图在本目录中的全部传送定义（装配器按图过滤消费）
static func by_map(map_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for spec: Dictionary in TELEPORTS:
		if String(spec["map"]) == map_name:
			out.append(spec)
	return out


## 触发器实体节点名（"Evt_" 前缀同内容点位命名空间约定，防与美术锚点重名）
static func entity_name(id: String) -> String:
	return "Evt_" + id
