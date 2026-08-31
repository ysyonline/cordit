extends Area2D
## trigger_teleport.gd —— E4-S6 传送触发器薄壳（A7 事件模板族，与 chest /
## investigate_point 同构）：只携带 teleport_id，全部行为读 TeleportCatalog。
##
## 【职责边界】本脚本不理解"传到哪、怎么传"——几何（触发区位置/尺寸）由
##   TeleportAssembler 程序化构建，行为分派统一走 _on_body_entered：
##   同图传送 = 改玩家位置 + 换相机限区（town_map 既有简版行为平移）；
##   跨图传送 = SceneRouter.change_scene（不带 payload）+ 自动存档请求。
##
## 【为什么是薄壳】拍板项④：E5 JSON 加载器就绪后事件行为整体回迁，届时
##   本脚本只换数据源（目录 → 加载器），协议（id + body_entered）不变。
##
## 【装配时序】由 TeleportAssembler.assemble() 在地图 _ready 中构建入树，
##   属性先设后入树（test_e4s4 spawn 纪律同款）；body_entered 在 _ready
##   内自接（Area2D 入树即生效）。

const TeleportCatalog := preload("res://scripts/events/teleport_catalog.gd")

## 全局唯一传送 id（= TeleportCatalog.TELEPORTS 主键）
var teleport_id: String = ""

## 跨图传送专用： town 室内门在对话期间不响应（对话 GDD §4 边缘 2）——
## 由地图侧 setup 注入 runner 引用；无对话装配的图（road/f1/f2/f3）为 null，
## 恒视为 idle。同图传送同样受此闸门约束（门在对话中被身体占住不重复触发）。
var _dialogue_runner: Node = null

## 防重入锁：跨图传送经 Router 有 0.4s 淡入淡出，期间玩家仍在触发区内，
## body_entered 不再发（区域没重进）；但同图传送落位紧邻触发区外侧一格，
## 若落位计算漂移可能原地重进——传送执行后 0.5s 内忽略再次触发。
var _cooldown: float = 0.0

## E5 回迁预留事件口（A7 模板协议：与 chest/investigate 同名方法）
## 注：传送事件不走对话，get_npc_id 仅作协议占位。
func get_npc_id() -> String:
	return "teleport_" + teleport_id


func get_event_id() -> String:
	return teleport_id


## 地图侧装配时注入对话运行器（无 runner 的图传 null 即可）
func setup(p_runner: Node) -> void:
	_dialogue_runner = p_runner


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node2D) -> void:
	# 只响应玩家实体（layer 16）；敌人/推拉物不触发传送
	if not (body is CharacterBody2D):
		return
	if body.collision_layer & 16 == 0:
		return
	# 对话期间触发器不响应（E1-S6 town 既有规则平移）
	if _dialogue_runner != null and not _dialogue_runner.is_idle():
		return
	# 冷却期内忽略（防同图落位贴边弹回循环）
	if _cooldown > 0.0:
		return
	var spec: Dictionary = TeleportCatalog.by_id(teleport_id)
	if spec.is_empty():
		push_warning("[TriggerTeleport] 未登记的 teleport_id \"%s\"，忽略" % teleport_id)
		return
	_cooldown = 0.5
	if String(spec["kind"]) == "cross_map":
		_do_cross_map(spec)
	else:
		_do_same_map(spec, body)


## 同图传送：改位置 + 换相机限区（town_map.gd _on_trigger_body_entered 行为平移）。
## 不触发存档（裁定：同图室内传送不存，理由见 TeleportCatalog 头注释）。
func _do_same_map(spec: Dictionary, body: Node2D) -> void:
	body.global_position = TeleportCatalog.tile_to_pixel(spec["target"])
	var cam: Camera2D = body.get_node_or_null("Camera2D")
	if cam != null and TeleportCatalog.SAME_MAP_LIMITS.has(teleport_id):
		var rect: Rect2i = TeleportCatalog.SAME_MAP_LIMITS[teleport_id]
		cam.limit_left = rect.position.x
		cam.limit_top = rect.position.y
		cam.limit_right = rect.position.x + rect.size.x
		cam.limit_bottom = rect.position.y + rect.size.y
		cam.reset_smoothing()
	print("[TriggerTeleport] 同图传送 %s -> %s" % [teleport_id, spec["target"]])


## 跨图传送：经 SceneRouter 换图（不带 payload，A5 只约束地图↔战斗）+ 存档请求。
## 存档语义：落位由目标图 _ready 完成（ENTRY_SPAWNS 一致性由目录保证），
## 目标图 map_ready 广播后由地图侧统一 save()（§3.4"过传送点存"时序）。
## 本方法只负责：切图 + 发 save_requested（SaveManager 不在此刻写盘——
## 写盘时点 = 目标图 map_ready，见 map_ready_notifier 侧）。
func _do_cross_map(spec: Dictionary) -> void:
	var to_map: String = String(spec["to_map"])
	var path: String = TeleportCatalog.MAP_SCENE_PATHS.get(to_map, "")
	if path.is_empty():
		push_warning("[TriggerTeleport] 目标图 \"%s\" 无场景路径登记，取消传送" % to_map)
		return
	# 受理与否由 Router 校验决定（结构缺失/切换中会被拒，日志可见）
	var accepted: bool = SceneRouter.change_scene(path, {}, false)
	if accepted and TeleportCatalog.CROSS_MAP_SAVE:
		# 存档请求先于换图完成发出：map_ready 时序由目标图侧兑现写盘，
		# 此信号仅作"本次传送要存档"的意图登记（消费端见 autosave_notifier）
		EventBus.save_requested.emit()
	print("[TriggerTeleport] 跨图传送 %s -> %s（受理=%s）" % [teleport_id, to_map, accepted])
