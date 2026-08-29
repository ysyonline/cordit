extends StaticBody2D
## npc.gd —— NPC 实体：占位矩形 + 交互碰撞（E1-S6）
##
## 【需求依据】EPIC-1.md E1-S6："npc.tscn（只带 npc_id）"；架构 A7：
##   NPC 节点只带 npc_id，对话按 phase 映射选对话 id（映射逻辑属事件层，
##   本 Story 最小版由 DialogueRunner 直按 npc_id -> 对话 JSON 文件名解析）。
##
## 【装配规格】与 player.tscn 占位同风格（美术线 R2/R3 到位后同规格换精灵）：
##   根节点 (0,0) = 脚底触地点（y-sort 排序基准，规则同 player.gd 头注释）；
##   ├── BodyRect   Sprite2D 载体     位置 (-8,-9)，绘制范围 x∈[-8,8] y∈[-18,0]
##   ├── Collision  CollisionShape2D  12x6 @ (0,-3)，只框"脚"（俯视惯例），
##                                    层 1（世界墙体）——挡玩家脚，与墙同性质；
##   └── InteractBody StaticBody2D    16x16 @ (0,-8)，层 2（交互物）——
##                                    被 player 的 InteractRay 命中即视为可交互。
##   【4.7.2 实测】交互判定体用 StaticBody2D 而非 Area2D：headless 探针矩阵
##   （11 组）实测 Area2D 形状对射线完全不可见（详见 npc.tscn 注记）——
##   层 2 StaticBody2D 不参与玩家 move_and_slide 碰撞（player 碰撞 mask=1），
##   仅作 InteractRay 标靶，"可交互体"语义与 Area2D 等价且 headless/实机一致。
##
## 【层位约定】（沿 player.tscn 头注释）：1=世界墙体 2=交互物 4=遮挡物。
##   NPC 脚部挡路（层1）+ 可交互（层2）两个身份用两个碰撞体分别表达——
##   InteractRay mask=3（层1|2）会先命中脚部碰撞体，见 get_npc_id() 说明。

## NPC 唯一标识：对话 JSON 文件解析键（data/json/dialogues/npc_<npc_id>.json）。
## 命名与 town.tscn 的 E1-S5 锚点对齐（如锚点 npc_01_innkeeper -> npc_01_innkeeper）。
@export var npc_id: String = ""

## 交互提示来源（调试用日志观察；"!"气泡属后续 Story）
var _display_name: String = ""


func _ready() -> void:
	# npc_id 兜底取场景节点名（12 锚点名即 npc_01_innkeeper 形态，直摆可用）
	if npc_id.is_empty():
		npc_id = String(name)
	# display_name 供 DialogueRunner 名字栏兜底（JSON 未给 speaker 时使用）
	_display_name = npc_id.erase(0, npc_id.find("_") + 1).capitalize() if npc_id.contains("_") else npc_id


## 对话发起入口：被玩家交互时由 trigger_dialogue 侧调用（薄壳约定，A7）。
## 返回 npc_id 供上层解析对话文件。
func get_npc_id() -> String:
	return npc_id
