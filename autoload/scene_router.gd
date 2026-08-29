extends Node
## SceneRouter —— 场景路由单例（Autoload 注册名：SceneRouter）
##
## 【职责】（架构文档 A3 / A4；本文件为 E1-S3 正式实现，取代 E1-S2 空壳）：
##   ① change_scene(path, payload)：唯一场景切换入口。切前先校验 payload
##      （A4："Router 切到任何场景前先检查 payload 合法性，不合法则拒绝切换
##      并打印原因"）；合法则执行 0.2s 淡出 → 换装 Main/World → 0.2s 淡入。
##   ② validate_payload(payload)：BattlePayload（A5 四字段协议）合法性校验，
##      逐条报告"缺字段 / 类型错"，供 change_scene 与冒烟测试直接调用。
##   ③ 载荷暂存：合法切换时把 payload 深拷贝暂存，战斗场景装载后经
##      get_staged_payload() 取回（A3"载荷暂存"职责的落地，地图与战斗零互引）。
##
## 【边界】（A3："不知道任何具体场景的内容，只管切"）：
##   - 不 import / 不引用任何具体地图、战斗场景；
##   - 不存游戏状态：current_scene_path 与 _staged_payload 是路由簿记
##     （"切到哪、带着什么切"），不是游戏状态（队伍/剧情等只在 GameData）；
##   - 不发业务信号：enemy_touched / battle_finished 由地图与战斗系统发射，
##     Router 一律不代发。
##
## 【map_ready 归属裁决】（保持 A3/A7 一致，本 Story 明确写明）：
##   EventBus.map_ready 的语义是"某张地图装载完成"，只有地图场景自己知道
##   "我是谁、何时算装载完成"（示范见 tests/smoke/fixtures/map_whitebox.gd）。
##   Router 若代发，就必须理解"我刚切的是不是地图"——违反 A3"不知道场景内容"。
##   因此：map_ready 由地图场景根脚本在 _ready 中发射，Router 不发、不监听。
##
## 【结构依赖】（A4）：Router 假定运行入口为 res://scenes/main.tscn：
##   Main（常驻根）
##   ├── World     ← 唯一的"当前场景容器"，Router 只替换其子节点
##   └── UILayer   ← CanvasLayer，跨场景常驻；内含过渡遮罩 FadeMask
##   找不到该结构时拒绝切换并打日志（保护 headless / F6 直启等无 Main 的运行）。
##
## 【与冒烟测试的对应】tests/smoke/SMOKE-CHECKLIST.md：
##   SMK-08 合法 payload 通过并切换 / SMK-09 非法拒绝且含原因 /
##   SMK-10 拒绝不破坏当前场景 / SMK-11 UILayer 跨场景存活。

# ------------------------------------------------------------------
# 常量
# ------------------------------------------------------------------

## BattlePayload 字段协议（架构 A5：字段名 -> 期望的 Variant.Type）。
## 校验规则：四字段全部必填、类型精确匹配（Vector2i 不冒充 Vector2）。
const PAYLOAD_FIELDS: Dictionary = {
	"enemy_group_id": TYPE_STRING,
	"return_map": TYPE_STRING,
	"return_position": TYPE_VECTOR2,
	"defeat_enemy_uid": TYPE_STRING,
}

## 淡出/淡入时长（秒）——A4 与 E1-S3 Story 钉定的 0.2s
const FADE_DURATION: float = 0.2

## A4 常驻根下的固定节点路径（与 scenes/main.tscn 结构一一对应）
const MAIN_NODE_PATH: String = "Main"
const WORLD_NODE_PATH: String = "World"
const FADE_MASK_NODE_PATH: String = "UILayer/FadeMask"

# ------------------------------------------------------------------
# 运行时簿记（路由元数据，非游戏状态——游戏状态只在 GameData，见 A3）
# ------------------------------------------------------------------

## 最近一次成功切换装入 World 的场景路径（res:// 完整路径）。
## 启动时 World 为空，此值为空串，由首次合法 change_scene 填充。
var current_scene_path: String = ""

## 最近一次合法切换暂存的 payload 深拷贝（A3"载荷暂存"）。
## 消费方：战斗场景装载后经 get_staged_payload() 读取，不经信号旁路、不互引。
var _staged_payload: Dictionary = {}

## 切换进行中标志（防重入：淡入淡出期间再调 change_scene 一律拒绝并打日志）
var _switching: bool = false


# ------------------------------------------------------------------
# 公开入口
# ------------------------------------------------------------------

## 场景切换唯一入口（前两参与 SMOKE-CHECKLIST SMK-08~12 的假定签名一致）。
## 第三参 p_has_payload：本次切换是否携带 BattlePayload——
##   战斗装载（地图→战斗）一律 true（默认）；地图装载（E1-S4 后大量使用）
##   没有 BattlePayload 协议可言（A5 只约束地图↔战斗），必须显式传 false 跳过
##   payload 校验，否则空字典会被 A5 四必填字段规则拒绝（无头自验已踩过此坑）。
## 返回 true = 已受理（0.2s 淡出 → 换装 → 0.2s 淡入 异步进行中）；
## 返回 false = 拒绝（原因见输出面板，[SceneRouter] 前缀）。
## 设计为同步返回：校验/拒绝路径零延迟返回，便于冒烟脚本同步断言返回值；
## 淡入淡出在内部协程完成，调用方无需 await 本函数。
func change_scene(path: String, payload: Dictionary = {}, p_has_payload: bool = true) -> bool:
	# 1) 防重入：切换期间不接受新请求（SMK-10"Router 不进坏状态"的保障之一）
	if _switching:
		print("[SceneRouter] 拒绝切换：上一轮切换（淡入淡出）尚未完成，拒绝重入")
		return false
	# 2) 路径合法性：拒绝一切装载不出来的目标（路径拼错 / 非场景资源）
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		print("[SceneRouter] 拒绝切换：目标路径不存在或不是场景（PackedScene）：\"", path, "\"")
		return false
	# 3) payload 校验（A4：切之前先检查；不合法 → 拒绝切换并打印原因）
	#    仅在"本次切换携带 BattlePayload"时执行（见上 p_has_payload 说明）
	if p_has_payload and not validate_payload(payload):
		print("[SceneRouter] 拒绝切换到 \"", path, "\"：BattlePayload 不合法（明细见上一行）")
		return false
	# 4) 结构依赖：A4 常驻根必须在场（新场景要装进 Main/World）
	var world: Node = _get_world()
	if world == null:
		print("[SceneRouter] 拒绝切换：未找到常驻根 Main/", WORLD_NODE_PATH,
				"（Router 依赖 A4 结构；请从 res://scenes/main.tscn 启动）")
		return false
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[SceneRouter] 拒绝切换：场景资源装载失败：\"", path, "\"")
		return false
	# 5) 受理：暂存 payload（深拷贝，调用方事后改字典不影响已存载荷），
	#    交内部协程执行 0.2s 淡出 → 换装 World → 0.2s 淡入
	_staged_payload = payload.duplicate(true)
	_switching = true
	_do_switch(world, packed, path)
	print("[SceneRouter] 受理切换 -> ", path)
	return true


## BattlePayload 校验（A5 四字段协议）。合法返回 true；不合法返回 false 并
## 逐条打印原因，明确区分"缺字段"与"类型错"（SMK-09 验收点）。
## 说明：协议外多余字段只警告不拒绝——A5 未来加字段时，旧调用方不被一票否决。
func validate_payload(payload: Dictionary) -> bool:
	var problems: Array[String] = []
	for field: String in PAYLOAD_FIELDS:
		var expected_type: int = PAYLOAD_FIELDS[field]
		if not payload.has(field):
			problems.append("缺字段 \"%s\"" % field)
		elif typeof(payload[field]) != expected_type:
			problems.append("类型错 \"%s\"：应为 %s，实为 %s" % [
					field, type_string(expected_type), type_string(typeof(payload[field]))])
	for field: String in payload:
		if not PAYLOAD_FIELDS.has(field):
			print("[SceneRouter] 警告：payload 含协议外字段 \"", field, "\"（放行不拒绝）")
	if not problems.is_empty():
		print("[SceneRouter] payload 校验失败：", "；".join(problems))
		return false
	return true


## 取回最近一次合法切换暂存的 payload（返回深拷贝；尚无暂存时为空字典）。
## 消费方：战斗场景装载后读取 BattlePayload（A3 载荷暂存职责的唯一读取口）。
func get_staged_payload() -> Dictionary:
	return _staged_payload.duplicate(true)


# ------------------------------------------------------------------
# 内部实现
# ------------------------------------------------------------------

## 内部协程：0.2s 淡出 → 换装 World → 0.2s 淡入。
## 由 change_scene 受理后发起（fire-and-forget），期间 _switching=true 挡重入；
## 全程黑幕之后才动场景树，任何失败都不在此层发生（失败早在受理前被拒绝）。
func _do_switch(world: Node, packed: PackedScene, path: String) -> void:
	var mask: ColorRect = _get_fade_mask()
	# 淡出（黑幕盖住画面）；结构异常导致无遮罩时退化为直接换装（不中断流程）
	if mask != null:
		mask.visible = true
		var fade_out: Tween = create_tween()
		fade_out.tween_property(mask, "modulate:a", 1.0, FADE_DURATION).from(0.0)
		await fade_out.finished
	# 换装：旧场景整棵排队释放（帧末安全析构），新场景接入 World
	for old: Node in world.get_children():
		old.queue_free()
	var new_scene: Node = packed.instantiate()
	world.add_child(new_scene)
	current_scene_path = path
	print("[SceneRouter] 装载完成 -> ", path)
	# 淡入（黑幕揭开）
	if mask != null:
		var fade_in: Tween = create_tween()
		fade_in.tween_property(mask, "modulate:a", 0.0, FADE_DURATION).from(1.0)
		await fade_in.finished
		mask.visible = false
	_switching = false


## 取 A4 常驻根中的 World（Main/World）；结构不存在时返回 null
func _get_world() -> Node:
	var main: Node = get_tree().root.get_node_or_null(MAIN_NODE_PATH)
	if main == null:
		return null
	return main.get_node_or_null(WORLD_NODE_PATH)


## 取 UILayer 下的过渡遮罩（Main/UILayer/FadeMask）；结构不存在时返回 null
func _get_fade_mask() -> ColorRect:
	var main: Node = get_tree().root.get_node_or_null(MAIN_NODE_PATH)
	if main == null:
		return null
	return main.get_node_or_null(FADE_MASK_NODE_PATH) as ColorRect
