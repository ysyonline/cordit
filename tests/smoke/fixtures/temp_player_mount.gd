extends Node
## temp_player_mount —— 临时玩家挂载器（E1-S4 测试用，EPIC-2 落正式系统后删除）
##
## 【职责】：_ready 时把 player.tscn 挂到 YSorted 容器（y-sort 生效前提：
## 玩家与遮挡物同父，见 player.gd 头注释规则②），位置取 PlayerSpawn 标记
## （脚底坐标）。
##
## 【边界】：仅测试场装配逻辑；无状态、不通信、不感知路由。
## 属性由 map_a.tscn 注入（player_scene），不硬编码场景路径。

## 玩家场景（tscn 内注入）
@export var player_scene: PackedScene

## 出生标记节点名（挂载器同图内查找）
const SPAWN_NODE_NAME: String = "PlayerSpawn"

## YSorted 容器节点名（与地图场景约定一致）
const YSORTED_NODE_NAME: String = "YSorted"


func _ready() -> void:
	if player_scene == null:
		push_error("[TempPlayerMount] 未注入 player_scene，玩家未挂载")
		return
	var map: Node = get_parent()
	var ysorted: Node = map.get_node_or_null(YSORTED_NODE_NAME)
	var spawn: Node2D = map.get_node_or_null(SPAWN_NODE_NAME) as Node2D
	if ysorted == null or spawn == null:
		push_error("[TempPlayerMount] 地图缺 %s / %s，玩家未挂载" % [YSORTED_NODE_NAME, SPAWN_NODE_NAME])
		return
	var player: Node = player_scene.instantiate()
	player.position = spawn.position
	ysorted.add_child(player)
	print("[TempPlayerMount] 玩家已挂载 -> %s/%s @ %s（脚底）" % [YSORTED_NODE_NAME, player.name, spawn.position])
