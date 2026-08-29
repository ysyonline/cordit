extends Area2D
## trigger_dialogue.gd —— 对话触发器薄壳（E1-S6，架构 A7 第 1 层）
##
## 【需求依据】架构 A7：触发器是薄壳——Area2D + 脚本，属性只有标识 id，
##   行为委托给数据（对话 JSON）；EPIC-1 E1-S6："trigger_dialogue 薄壳"。
##   探索 GDD §3.3：交互键 Z/E 均有效，检测范围 = 玩家面前 1 格 + 自身所在格。
##
## 【薄壳纪律】本脚本不做对话选择逻辑（phase 映射属事件层，EPIC-2）：
##   只把"玩家面前命中了我 → 让 DialogueRunner 按 npc_id 开对话"这一件事做掉。
##
## 【检测归属说明】"面前 1 格 + 所在格"的几何判定由 player 侧的 InteractRay
##   承担（E1-S4 预装：射线从胸口出发指向面朝方向 20px，命中半径天然覆盖
##   "面前 1 格"；玩家与 NPC 相邻站立即"所在格"贴近）。本脚本是被命中方，
##   不重复做几何检测——两边各做一半会引入两套判定漂移。
##   事件轮询（谁按了 Z/E）放在地图装配层的 interaction_controller.gd：
##   薄壳保持零 _process、零输入轮询，只提供"被交互时干什么"。
##
## 【事件系统边界】完整事件 JSON 加载器（conditions/actions 动作执行）属
##   EPIC-2。本版 dialogue_id 直接映射：交互目标带 get_npc_id() →
##   DialogueRunner.start_dialogue(npc_id)。

## 事件标识（A7 薄壳协议属性；本版冗余存放，供未来事件系统直接挂接）
@export var event_id: String = "trigger_dialogue"
