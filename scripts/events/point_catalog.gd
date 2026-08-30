extends RefCounted
## point_catalog.gd —— E4-S5 全部 27 内容点位结构化数据表（点位数据正本）
##
## 【拍板项④落地】EPIC-5 JSON 事件加载器未就绪 → 本 Story 硬编码触发器
##   先行，但 27 点位数据（坐标 + 内容）必须结构化落盘，保证 E5 回迁时
##   数据可平移：本表即数据源，data/json/events/chests.json（9）与
##   investigates.json（18）为同构 JSON 镜像（E5 加载器读 JSON 后本表
##   降级为校验锚或直接删除）。
##
## 【坐标口径】全部为 tile 坐标 (tx, ty)，装配时转像素 tile*16+8（格中心）。
##   选点原则（探索 GDD §3.1/§3.3 + 任务卡）：
##   - GDD §3.4 spawn 八格安全区约束对象是「敌人初始位与碰撞」，内容点
##     不占敌人配额；工程底线 = 点位不压 spawn 落位格（≥2 格，防出生点
##     嵌交互体挡路），见 test_17 注记；
##   - 宝箱常在敌人身后/支路（"风险自选"：拿宝箱需绕过或打过守箱敌人）；
##   - 调查点沿主路径与角落均匀铺开（§3.1 密度校验：每 8-20s 一发现）。
##   逐点设计意图见 data/json/events/chests.json 与 flavor 文案表注记。
##
## 【与既有锚点的关系】road/f1/f2/f3 的 21 个锚点（E4-S2/S3 摆放，
##   Marker2D 名 Chest_*/Investigate_*）与本表逐一对应【坐标一致】；
##   town 的 6 个调查点为本次新增（E1-S5 制作单未含调查点锚点）。
##
## 【字段】id（全局唯一，= 存档 chests_opened 键 / 事件 event_id 源）、
##   tile: Vector2i、item_id/item_count（仅宝箱）、sfx 钩子（仅宝箱）。
##   dialogue_id 不入表：由命名约定派生（宝箱 dlg_chest_<id>.json；
##   调查 flavor_inv_<id>.json，一文件一脚本，文件名即对话 id——E1-S6
##   runner 契约）。

## 五图 spawn 落位（tile 坐标，供"8 格安全区"校验用；像素位 = *16+8）
const SPAWNS: Dictionary = {
	"town": Vector2i(12, 40),   # town.tscn 玩家出生 (192,640)
	"road": Vector2i(24, 4),    # road.tscn from_town (384,64)
	"ruins_f1": Vector2i(28, 3),# ruins_f1.tscn from_road (448,56)
	"ruins_f2": Vector2i(24, 2),# ruins_f2.tscn from_f1 (384,40)
	"ruins_f3": Vector2i(20, 2),# ruins_f3.tscn from_f2 (320,40)
}

# ------------------------------------------------------------------
# 宝箱 9（对表探索 GDD §3.1 总表行：town1 / road2 / f1-3 / f2-2 / f3-1）
# 守箱/支路设计意图注释在行尾（§3.3"风险自选"）
# ------------------------------------------------------------------
const CHESTS: Array[Dictionary] = [
	# —— town（1）：锚点 Chest_town_01 (59,22)，市场街尽头，无守敌（安全图）
	{"id": "chest_town_01", "map": "town", "tile": Vector2i(59, 22),
		"item_id": "potion_m", "count": 1},
	# —— road（2）：Chest_road_01 在 moth 巡逻线南侧支路（绕过即拿，擦身而过）；
	#    Chest_road_02 在南门西侧断桥死角，beetle_01 巡逻线边缘（贴近再拿）
	{"id": "chest_road_01", "map": "road", "tile": Vector2i(9, 16),
		"item_id": "potion_s", "count": 2},
	{"id": "chest_road_02", "map": "road", "tile": Vector2i(36, 62),
		"item_id": "antidote", "count": 1},
	# —— f1（3）：01 西翼死路（salamander 视野外）；02 东北高台（crystal 巡逻
	#    线背后）；03 中部石阵（两敌巡逻圈之间的凹地，时机拿取）
	{"id": "chest_f1_01", "map": "ruins_f1", "tile": Vector2i(4, 20),
		"item_id": "ether_s", "count": 1},
	{"id": "chest_f1_02", "map": "ruins_f1", "tile": Vector2i(50, 9),
		"item_id": "potion_m", "count": 1},
	{"id": "chest_f1_03", "map": "ruins_f1", "tile": Vector2i(24, 39),
		"item_id": "potion_s", "count": 1},
	# —— f2（2）：01 西厅（guardian 视野圈外绕行）；02 东侧支路（引开精英的
	#    时机奖励）；均离 guardian 定守位 (23,24) ≥ 6 格
	{"id": "chest_f2_01", "map": "ruins_f2", "tile": Vector2i(8, 20),
		"item_id": "potion_l", "count": 1},
	{"id": "chest_f2_02", "map": "ruins_f2", "tile": Vector2i(38, 27),
		"item_id": "potion_m", "count": 1},
	# —— f3（1）：Boss 门左侧凹格（Boss 战前最后补给，I5 事件链顺路可达）
	{"id": "chest_f3_01", "map": "ruins_f3", "tile": Vector2i(21, 35),
		"item_id": "potion_l", "count": 1},
]

# ------------------------------------------------------------------
# 调查点 18（town6 / road3 / f1-4 / f2-3 / f3-2）
# 注：road/f1/f2/f3 的 14 个坐标与既有 Marker2D 锚点一致（tile=像素/16-0.5
#   反推，见 _verify_anchors 对表测试）；town 6 个为本次新增选点。
# 文案方向注记：A=世界观氛围 / F=纯趣味（各 50%，写作分工见 flavor 文案表）
# ------------------------------------------------------------------
const INVESTIGATES: Array[Dictionary] = [
	# —— town（6，新增）：广场喷泉(F)、北门告示板(A)、客栈后巷木桶(F)、
	#    神社石像(A)、东街路灯(F)、民居窗台花盆(F)
	#    【注】tone 以落盘文案实际笔触为准（A=世界观氛围钩子 / F=纯趣味），
	#    每条文案与 flavor_inv_<id>.json 一一对应，见 §H 文案资产校验。
	{"id": "inv_town_01", "map": "town", "tile": Vector2i(25, 26), "tone": "F"},
	{"id": "inv_town_02", "map": "town", "tile": Vector2i(30, 10), "tone": "A"},
	{"id": "inv_town_03", "map": "town", "tile": Vector2i(20, 33), "tone": "F"},
	{"id": "inv_town_04", "map": "town", "tile": Vector2i(39, 16), "tone": "A"},
	{"id": "inv_town_05", "map": "town", "tile": Vector2i(44, 30), "tone": "F"},
	{"id": "inv_town_06", "map": "town", "tile": Vector2i(16, 22), "tone": "F"},
	# —— road（3，锚点同位）：断桥警示桩(F)、石像底座(F)、路旁界碑(A)
	{"id": "inv_road_01", "map": "road", "tile": Vector2i(38, 10), "tone": "F"},
	{"id": "inv_road_02", "map": "road", "tile": Vector2i(34, 28), "tone": "F"},
	{"id": "inv_road_03", "map": "road", "tile": Vector2i(24, 38), "tone": "A"},
	# —— f1（4，锚点同位）：入口浮雕(A)、坍柱刻痕(A)、残破供桌(F)、苔藓石缝(F)
	{"id": "inv_f1_01", "map": "ruins_f1", "tile": Vector2i(32, 2), "tone": "A"},
	{"id": "inv_f1_02", "map": "ruins_f1", "tile": Vector2i(30, 11), "tone": "A"},
	{"id": "inv_f1_03", "map": "ruins_f1", "tile": Vector2i(28, 23), "tone": "F"},
	{"id": "inv_f1_04", "map": "ruins_f1", "tile": Vector2i(18, 37), "tone": "F"},
	# —— f2（3）：遗像基座(A)、断裂锁链(A)、墙角刻字(F)
	#    【回归锚点位】01/02 坐标 = 既有 Investigate_ruins_f2_01/02 锚点
	#    （E4-S3 已验收的美术正本，实体必须同位否则美术道具变死物）。
	#    01 原锚点 (21,2) 离 spawn 3 格：GDD §3.4 八格安全区约束对象是
	#    「敌人初始位与碰撞」，内容点不占敌人配额、spawn 落位格无实体，
	#    不构成违规（test_17 只守"不压 spawn 落位"底线）。
	{"id": "inv_f2_01", "map": "ruins_f2", "tile": Vector2i(21, 2), "tone": "A"},
	{"id": "inv_f2_02", "map": "ruins_f2", "tile": Vector2i(38, 10), "tone": "A"},
	{"id": "inv_f2_03", "map": "ruins_f2", "tile": Vector2i(14, 41), "tone": "F"},
	# —— f3（2，锚点同位）：石棺铭文(A)、灰石 Boss 门裂痕(A)
	{"id": "inv_f3_01", "map": "ruins_f3", "tile": Vector2i(18, 35), "tone": "A"},
	{"id": "inv_f3_02", "map": "ruins_f3", "tile": Vector2i(12, 16), "tone": "A"},
]


## 图名 → 场景节点内的实体容器路径（town 的宝箱锚点直接挂 YSorted，
## 其余图挂 YSorted/Anchors——E4-S2/S3 既有布局，装配时按此对号）
static func anchor_parent(map_name: String) -> String:
	if map_name == "town":
		return "YSorted"
	return "YSorted/Anchors"


## 命名约定：实体节点名（"Evt_" 前缀 + 点位 id，全局唯一）。
## 【勿用锚点名命名实体】town 的 Chest_town_01 美术 Marker2D 已存在，
## 同名 add_child 会被引擎强制改名（@前缀）且污染锚点查找——实体与
## 美术锚点是两类节点，命名空间必须分开。
static func chest_entity_name(id: String) -> String:
	return "Evt_" + id


## 命名约定：调查点实体节点名
static func inv_entity_name(id: String) -> String:
	return "Evt_" + id


## 命名约定：既有宝箱美术锚点名（E4-S2/S3 制作对表名，对表测试用）
static func chest_anchor_name(id: String) -> String:
	var parts: PackedStringArray = id.split("_")
	# chest_town_01 -> Chest_town_01；chest_f1_01 -> Chest_ruins_f1_01
	if parts[1] == "town" or parts[1] == "road":
		return "Chest_%s_%s" % [parts[1], parts[2]]
	return "Chest_ruins_%s_%s" % [parts[1], parts[2]]


## 命名约定：既有调查点美术锚点名（town 6 点为新增、无锚点，返回值仅供对表）
static func inv_anchor_name(id: String) -> String:
	var parts: PackedStringArray = id.split("_")
	# inv_town_01 -> Investigate_town_01；inv_f1_01 -> Investigate_ruins_f1_01
	if parts[1] == "town" or parts[1] == "road":
		return "Investigate_%s_%s" % [parts[1], parts[2]]
	return "Investigate_ruins_%s_%s" % [parts[1], parts[2]]
