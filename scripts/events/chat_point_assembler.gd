extends RefCounted
## chat_point_assembler.gd —— 队员聊天点装配器（T4.2，E6-S4 第 2 步）
##
## 【需求依据】E6-S4 验收条①原文"两段聊天各在指定位置触发一次"——
##   触发点为【位置触发】（对话 GDD §3.5 预算表：P1 道路 1 段 / P2 遗迹二层
##   1 段；探索 GDD §3.1 f2 行"队员聊天点"）。任务书建议的"存/读档成功"
##   触发与验收条冲突，按裁定以验收条为准（存档点在 town 室内、读档无
##   固定位置，非 GDD 指定位置）。
##
## 【为什么是"事件薄壳"而非新触发器类型】E5-S2 起 trigger_event_shell 是
##   事件数据就绪触发器的统一收敛形态（薄壳协议：递 id、把数据递给执行器，
##   壳里零事件语义）；一次性的语义不进壳，在事件数据侧用 E5 既有
##   "conditions.not_flag 门闸 + actions.set_flag 登记"表达（与宝箱已开
##   判定同构，f3 Boss 锚点同款薄壳复用）——不发明新触发机制，同 E5 口径。
##
## 【一次性口径】首次触发开演并 set_flag 落 GameData.flags（E5-S3 起入
##   存档 schema，跨存读档持久）；重复踩踏被 not_flag 门闸拒绝、零动作。
##   聊天属剧情氛围内容，删档/回档后随 flags 回滚重新可触发（剧情事件
##   一致的既有语义，不作对话历史去重）。
##
## 【碰撞位约定】踩踏面 mask=16（玩家实体层，E2-S2 回归修复口径，
##   teleport_assembler 同款）；壳自身 layer=0（不被交互射线检测——
##   本点位纯踩踏，交互分派面不挂协议）。
##
## 【克隆关系】结构克隆 ruins_f3_map._assemble_boss_anchor（薄壳三件套
##   装配 + InteractShape 16×16）与 teleport_assemble（目录驱动、Area2D
##   程序化构建）两先例；目录（坐标/事件 id）在本表，点数极少（2），
##   不另开 JSON 点位镜像（PointCatalog 回迁形态不动）。

const EventLoader := preload("res://scripts/events/event_loader.gd")
const ShellScript := preload("res://scripts/events/trigger_event_shell.gd")

## 队员聊天点目录（tile 坐标，装配转像素 tx*16+8 格中心，PointCatalog 口径；
## size_tiles = 命中区格数，缺省 2×2）。选点 = BFS 主路径近心位（两图均
## detour≈0，直走主线必经），事件侧 story_phase 门闸保证"该来的时段才响"：
##   road  (35,31)：第三林带 (31,{35,36}) 开口正后方 1 格，承北（镇）向南
##     （遗迹）推进的中段；phase>=1（P1 异变+出发）才触发，重复踩踏幂等。
##     【T4.3 扩区拍板】命中区 3×2：y=31/32 林墙带仅 x=35/36 可走，2×2 以
##     锚点格为中心只覆盖 35 整格 + 邻格各半（8px 条带），主线右侧半格
##     有绕行擦边错过风险；扩为 3×2 后 x=34..36 整格全覆盖（34 列为墙，
##     纯冗余安全边），锚点 (35,31) 位置语义不变。
##   f2    (23,8)：入口前厅走廊收窄处，from_f1 入图即经（最短路 detour=0）；
##     phase>=2（进遗迹调查）才触发。命中区维持 2×2（走廊 2 宽 x=23/24，
##     2×2 全覆盖无扩区必要）。
##   挂 YSorted/Anchors 容器（road/f2 既有锚点容器，无美术锚点位——聊天点
##   纯功能位）。
const CHAT_POINTS: Array[Dictionary] = [
	{
		"id": "chat_road_01", "map": "road",
		"event_id": "party_chat_road_01",
		"tile": Vector2i(35, 31),
		"size_tiles": Vector2i(3, 2),
	},
	{
		"id": "chat_f2_01", "map": "ruins_f2",
		"event_id": "party_chat_f2_01",
		"tile": Vector2i(23, 8),
		"size_tiles": Vector2i(2, 2),
	},
]

## 命中区缺省格数（未带 size_tiles 字段的目录条目兜底；2×2 = 32×32 px，
## 踩踏触发器常规规格）
const DEFAULT_SIZE_TILES: Vector2i = Vector2i(2, 2)


## 装配一张图的全部聊天点。
## p_map_root：地图场景根（须含 YSorted/Anchors 容器，road/f2 均已有）；
## p_map_name：目录键（CHAT_POINTS.map 字段值）；p_runner：对话运行器
## （门闸与 dialogue 动作消费；null 允许——门闸跳过、开演留日志，headless
## 纯装配面不炸，与 f3 锚点 runner 兜底同口径）。
## 返回装配的触发器数组（测试对表用）。
static func assemble(p_map_root: Node, p_map_name: String, p_runner: Node = null) -> Array:
	var container: Node = p_map_root.get_node_or_null("YSorted/Anchors")
	if container == null:
		push_warning("[ChatPointAssembler] %s 无 YSorted/Anchors 容器，聊天点装配跳过" % p_map_name)
		return []
	# 全局 executor 复用（Router 装配单例；battle 挂起簿记/胜利续行全局唯一载体
	# ——f3 锚点装配同款）。road/f2 地图脚本无 event_executor 属性（get 返 null）
	# → 兜底取 SceneRouter 全局实例（生产面）；loader 按需自建（纯数据缓存）。
	# runner 三级兜底：装配注入 → 地图脚本引用（f3 形态）→ UILayer 常驻实例
	# （真实游戏主装配）。均缺（headless 纯装配面）：null 直递——门闸跳过、
	# dialogue 动作留日志跳过（事件层既有降级口径，不炸）。
	var executor: Variant = p_map_root.get("event_executor")
	if executor == null:
		executor = SceneRouter.global_event_executor
	var runner: Node = p_runner
	if runner == null:
		runner = p_map_root.get("dialogue_runner")
	if runner == null and p_map_root.is_inside_tree():
		var tree: SceneTree = p_map_root.get_tree()
		if tree != null:
			runner = tree.root.get_node_or_null("Main/UILayer/DialogueRunner")
	# R5 修复：全局 executor 是共享单例（Router 装配），壳的 setup 只把 runner
	# 存到壳自身做门闸，executor.dialogue_runner 仍为 null → dialogue 动作被
	# 跳过。f3 Boss 锚点（ruins_f3_map.gd）装配前显式 gexec.setup(runner)，
	# 聊天点装配漏了这步。has_dialogue_runner() 守卫防跨图重复注入（幂等）。
	if runner != null and executor != null and executor.has_method("setup") \
			and executor.has_method("has_dialogue_runner") \
			and not executor.has_dialogue_runner():
		executor.setup(runner)
		print("[ChatPointAssembler] 全局 executor 已注入 runner（R5 修复）")
	var loader: RefCounted = EventLoader.new()
	loader.load_all()
	var built: Array = []
	for spec: Dictionary in CHAT_POINTS:
		if String(spec["map"]) != p_map_name:
			continue
		var trigger: Area2D = _build_trigger(spec, loader, executor, runner)
		container.add_child(trigger)
		built.append(trigger)
	print("[ChatPointAssembler] %s 装配完成：聊天点 %d 处" % [p_map_name, built.size()])
	return built


## 触发器实体：先设属性后入树（_ready 前属性就位，map_events 纪律）。
## 薄壳三件套：loader（按需自建）+ executor（复用地图引用的全局单例）+
## runner（门闸 + dialogue 动作消费）。event_id 带 chat_ 前缀（调试定位，
## f3 锚点 boss_anchor_ 前缀同款）。
static func _build_trigger(p_spec: Dictionary, p_loader: Variant,
		p_executor: Variant, p_runner: Node) -> Area2D:
	var tile: Vector2i = p_spec["tile"]
	var size_tiles: Vector2i = p_spec.get("size_tiles", DEFAULT_SIZE_TILES)
	var trigger: Area2D = Area2D.new()
	trigger.set_script(ShellScript)
	trigger.name = "Evt_" + String(p_spec["id"])
	trigger.event_id = "chat_point_" + String(p_spec["id"])
	trigger.new_event_id = String(p_spec["event_id"])
	trigger.setup(p_loader, p_executor, p_runner)
	trigger.collision_layer = 0   # 纯踩踏面：自身不被交互射线检测
	trigger.collision_mask = 16   # 玩家实体层（E2-S2 修复口径）
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_tiles.x * 16.0, size_tiles.y * 16.0)
	shape_node.shape = rect
	trigger.add_child(shape_node)
	# 位置 = 锚点格中心（tile*16+8）：命中区以锚点格为几何中心展开，
	# road 3×2 覆盖 x=34..36 / y=31..32 整格（开口 35/36 全覆盖 + 墙侧冗余）
	trigger.position = Vector2(tile.x * 16 + 8, tile.y * 16 + 8)
	return trigger
