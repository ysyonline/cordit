extends Node
## battle_event_bridge —— 事件流战斗暂停/恢复桥（E5-S5，对话 GDD §6"对战斗"）
##
## 【需求依据】探索 GDD I5 回签：story_boss_pre 全序列"战前台词 → battle →
##   胜利续行 → 战后台词 → set_story_phase(3) → save_point"一次触发避免中途
##   态；battle 动作把事件流暂停交给战斗、胜利后恢复执行（EPIC-5 E5-S5）。
##
## 【为什么由 SceneRouter 装配、且必须常驻】同族先例 battle_result_handler：
##   battle_finished 发出时的场景时序——旧地图已随战斗转场销毁、新地图由
##   Router 回图逻辑装载——挂地图下必然收不到信号，事件流簿记随图湮灭等于
##   悬挂。桥必须跨场景常驻；Router 是既有"enemy_touched / battle_finished
##   接线 + 常驻装配"收口点，本桥属同一 A5 数据流的事件侧支线，装配内聚于
##   此。架构红线"4 Autoload 冻结"不触碰：普通 Node，非 Autoload。
##
## 【三路径语义】（类名 = 任务书"暂停/恢复/失败"三路径的落点）：
##   暂停：EventExecutor._start_battle 挂起事件流（簿记在 executor，本桥不
##         复制状态）→ enemy_touched（本桥监听）→ 补全回程字段后转发原载荷
##         → Router 转场。return_map/return_position 由地图侧职责（A3 边界
##         裁决：executor 不感知坐标）——Boss 事件固定回本图棺前位（I5 唯
##         一用例，数据面即事件本身，无需通用化）。
##   恢复：battle_finished(VICTORY) → 延迟两帧续行（帧序：battle 动作侧
##         call_deferred 的 force_idle 先收束对话——当场收束会改写调用方刚
##         消费的 is_idle 门闸状态，S2 同款坑；次帧 resolve_victory 执行战
##         后段。续行只动数据与信号，不等转场 tween 完成）。执行体 = 簿记
##         里的 executor：地图装配复用全局单实例（见 f3 装配），事件簿记
##         跨场景存活。
##   失败：battle_finished(DEFEAT) → clear_battle_pause() 清簿记（E4-S7
##         DEFEAT 读档已把 GameData 整体回滚到进图存档点；事件侧 story_boss_pre
##         战前段无前置写操作，簿记清空 + 无中途态 = 从头可再触发）。
##         ESCAPE：与失败同口径清场（Boss 战逃跑禁用属战斗侧，防御清场无害）。
##
## 【三重防护】暂停簿记只在 battle 动作置位、本桥三处消费清场——单测直驱
##   executor 的存量用例（e5s2 Group G）经 clear_battle_pause/after_each
##   隔离；桥在无簿记时收到 VICTORY 仅日志忽略（普通遇敌战斗不炸）。
##
## 【边界】不写 GameData（胜利副作用全部在续行 actions 里）、不引用具体
##   地图/战斗场景、簿记只有事件流指针与转发标志（A3：路由/桥接无游戏状态）。

## Boss 事件回程常量（I5 唯一用例；地图侧职责由本桥代组——executor 不持坐标）
const BOSS_RETURN_MAP: String = "res://scenes/maps/ruins_f3.tscn"
const BOSS_RETURN_TILE: Vector2 = Vector2(19.5, 35.5)   # 棺前触发格（gen_ruins Boss 锚 (19-20,35) 中缝）

## 事件流暂停簿记：{"executor": RefCounted}——enemy_touched 转发受理后登记，
## battle_finished 分岔消费后清空。空字典 = 无挂起（has_pending_event_battle 查询口）。
var _pending: Dictionary = {}

## 全局事件执行器引用（SceneRouter 装配单例；_ready 登记。暂停判据 =
## 敌我信号发出方是否即本实例的挂起簿记——普通遇敌零簿记直通）
var _global_executor: RefCounted = null


func _ready() -> void:
	EventBus.enemy_touched.connect(_on_enemy_touched)
	EventBus.battle_finished.connect(_on_battle_finished)
	# 全局 executor 登记（SceneRouter._ready 建好后才装配本桥——子节点顺序
	# 保证）：battle 动作的挂起簿记宿主即它，转场/续行全走同一实例
	_global_executor = SceneRouter.global_event_executor


## 暂停路径：battle 动作发出的 enemy_touched 转发口。
## 判据 = 载荷带 _from_event_battle 标记（executor._start_battle 写入；普通
## 遇敌 visible_enemy 组装的载荷无此键 → 直通返回，本桥零感知）。
## 事件战斗：登记挂起执行器 + 补全回程字段 → 转发给 Router（本桥是事件战斗
## 唯一受理转发方——Router._on_enemy_touched 对带 _from_event_battle 哨兵的
## 载荷直通跳过（dryrun8 补丁），不存在"Router 先受理空载荷占住 _switching 闸"
## 的双切换竞态；普通遇敌载荷无哨兵，仍走 Router 直通链路）。
func _on_enemy_touched(payload: Dictionary) -> void:
	# 勿在此判 _pending.is_empty() 提前返回——簿记只在本函数内置位，空簿记
	# 返回会把登记路径整个堵死（鸡生蛋死锁：真实游戏 Boss 胜利后永续行不了）。
	# 判别职责完全交给哨兵键：普通遇敌载荷（无 _from_event_battle）直接返回，
	# 直通既有链路；事件战斗载荷才登记簿记并转发。
	if payload.get("_from_event_battle", false) != true or not is_instance_valid(_global_executor):
		return
	var exec: RefCounted = _global_executor
	if not exec.in_battle_pause():
		# 簿记已在别处消费/清除（防御）：清登记，不留悬挂
		_pending = {}
		return
	var forwarded: Dictionary = payload.duplicate(true)
	forwarded.erase("_from_event_battle")
	forwarded["return_map"] = BOSS_RETURN_MAP
	forwarded["return_position"] = _tile_to_pixel(BOSS_RETURN_TILE)
	_pending = {"executor": exec}
	SceneRouter.change_scene(SceneRouter.BATTLE_SCENE_PATH, forwarded, true)
	print("[BattleEventBridge] 事件战斗转发：group=%s 回程 %s @ %s（胜利续行待 battle_finished）" % [
			String(exec.pending_battle_group), BOSS_RETURN_MAP, forwarded["return_position"]])


## 恢复/失败路径：battle_finished 分岔（VICTORY 续行 / DEFEAT·ESCAPE 清场）。
## 失败清场即时（DEFEAT 读档由 BattleResultHandler 同步执行，簿记清理无时序
## 依赖）；胜利续行延迟两帧（① force_idle 本身延迟一帧收束对话，② 转场
## tween 异步——续行只动数据与信号，不等转场完成，两帧后执行时序确定）。
func _on_battle_finished(result: Dictionary) -> void:
	if _pending.is_empty():
		return   # 普通遇敌战斗：事件流无簿记，全部交还既有链路
	var exec: RefCounted = _pending["executor"]
	_pending = {}
	if not is_instance_valid(exec):
		print("[BattleEventBridge] 挂起执行器已失效，事件流簿记丢弃")
		return
	var outcome: String = String(result.get("outcome", ""))
	if outcome != "VICTORY":
		exec.clear_battle_pause()
		print("[BattleEventBridge] %s：事件流簿记清空（读档回滚后事件可从头再触发）" % outcome)
		return
	# 胜利：双延迟收束后在新图 executor 上续行（语义见函数头注）
	_resolve_victory_deferred.call_deferred(exec)


## 胜利续行的帧序控制（两段 call_deferred 串行）：
##   帧+1：等待 executor 侧 call_deferred("force_idle") 先执行（battle 动作
##         已排队；此处不重复收束——executor 未注入 runner 时无排队亦无害）
##   帧+2：resolve_victory 执行战后续行段（set_story_phase / save_point / …）
func _resolve_victory_deferred(exec: RefCounted) -> void:
	if not is_instance_valid(exec):
		return
	_do_resolve.call_deferred(exec)


## 帧+2 实执行：胜利续行（防御：期间簿记被清则放弃——含 resolve_victory
## 自身的"无挂起忽略"日志，本处不再重复打印）
func _do_resolve(exec: RefCounted) -> void:
	if not is_instance_valid(exec) or not exec.in_battle_pause():
		return
	print("[BattleEventBridge] VICTORY：恢复事件流 → 战后续行段")
	exec.resolve_victory()


## 测试观察口：当前是否存在事件流战斗簿记（headless 断言用）
func has_pending_event_battle() -> bool:
	return not _pending.is_empty()


## 清空簿记（测试隔离用，与 executor.clear_battle_pause() 对称——e2 式登记
## 用例若只清 executor 不清桥，簿记会泄漏到后续用例：e3 曾中招）
func clear_pending() -> void:
	_pending = {}


## tile 坐标（可含 .5 半格）→ 格中心像素（TeleportCatalog.tile_to_pixel 同口径；
## 不直接 preload 目录类——本桥与传送目录无依赖关系，公式单点注释即锚）
func _tile_to_pixel(t: Vector2) -> Vector2:
	return Vector2(t.x * 16.0 + 8.0, t.y * 16.0 + 8.0)
