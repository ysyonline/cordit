extends RefCounted
## portrait_catalog.gd —— 对话头像差分目录（E5-S1，对话 GDD §3.1/§4）
##
## 【需求依据】对话 GDD §3.1 字段表：portrait = 头像差分 id（如 kyle_normal /
##   rina_smile），缺省沿用上一条；§4：头像窗（左侧，差分切换）——头像差分
##   用静态贴图换帧，不做立绘动画。
##
## 【⚠️ 网格修正（2026-09-05，用户试玩反馈"对话没头像"根因）】本集散图
##   （288×400）顶部 y∈[0,144) 为标题/栏目头带（"48x48 Faces 1st sheet"字样、
##   UPDATE/ORIGINAL 分节条），**人脸行实际 y = 144 / 192 / 288 / 336**。
##   旧表按 y=row×48 取图，把标题条裁成了"头像"——头像窗因此显示的是
##   米色纸带碎片，视觉上等于没头像。已按像素统计 + 逐格裁切目检修正。
##
## 【差分语义（占位声明）】四行并非表情差分，而是 UPDATE/ORIGINAL 两个
##   美术版本 × 各 2 变体。占位口径：row0=normal / row1=smile / row2=angry
##   （row3 备用）。正式表情排位待美术 intake（assets/CREDITS.md 流程）后换表。
##
## 【NPC 登记（2026-09-05，B 方案）】6 列 × 4 行 = 24 格：三主角各占 3 格
##   （normal/smile/angry），14 名 NPC 各占 1 格（*_normal），余 1 格备用。
##   全部为工程占位选脸，非角色正式形象。
##
## 【显示口径】区域裁切恒为 48×48（AtlasTexture）；对话框内按 2× 整数放大
##   到 96×96 显示（Nearest 采样、project.godot default_texture_filter=0，
##   整数倍无插值糊化）。此为用户 2026-09-05 拍板推翻"48 原生零缩放"旧冻结，
##   详见 dialogue_box.gd 头注与 sprint 记录。
##
## 【边界】纯静态工具：无状态、无节点依赖（scripts/core 纪律同款）。
##   未知 id / 空串返回 null——对话框隐藏头像窗（优雅降级：旁白、残响·男声/
##   女声等无脸说话者不报错）。

## 头像集散图（48×48 Faces 1st Sheet，CC-BY 3.0，授权见 assets/licenses/notices/48x48-faces.txt）
const FACE_SHEET: Texture2D = preload("res://assets/faces/48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png")

## 单格边长（贴图区域原生 48×48；显示层 2× 见 dialogue_box.gd）
const CELL_SIZE: int = 48

## 人脸行 y 坐标（行索引 → 集散图像素 y；顶部 0~144 为标题带不入表）
const FACE_ROW_Y: Array = [144, 192, 288, 336]

## 差分 id → 集散图区块 [col, row_index]（0 起；row_index 查 FACE_ROW_Y）
const PORTRAIT_REGIONS: Dictionary = {
	# ── 三主角（占位差分：normal/smile/angry）──
	"kai_normal": [0, 0], "kai_smile": [0, 1], "kai_angry": [0, 2],
	"kyle_normal": [0, 0], "kyle_smile": [0, 1], "kyle_angry": [0, 2],
	"rina_normal": [1, 0], "rina_smile": [1, 1], "rina_angry": [1, 2],
	"mona_normal": [2, 0], "mona_smile": [2, 1], "mona_angry": [2, 2],
	# ── 镇上 NPC（各 1 格占位）──
	"guard_normal": [0, 3],      # 镇口守卫
	"kana_normal": [1, 3],       # 主妇卡娜
	"priest_normal": [2, 3],     # 神官梅尔
	"traveler_normal": [3, 0],   # 神秘旅行者（蒙面——神秘感贴合）
	"kid_normal": [3, 1],        # 追风的小孩（粉发——顽皮感贴合）
	"porter_normal": [3, 2],     # 搬运工老壮
	"peddler_normal": [3, 3],    # 货郎阿六
	"shepherd_normal": [4, 0],   # 牧羊少年
	"lian_normal": [4, 1],       # 莉安大婶
	"smith_normal": [4, 2],      # 铁匠老葛
	"innkeeper_normal": [4, 3],  # 客栈老板
	"elder_normal": [5, 0],      # 村中长老（光头老者贴合）
	"prayer_normal": [5, 1],     # 祈祷的大婶
	"fiona_normal": [5, 2],      # 菲奥拉（黑发女子——神秘感贴合）
}


## 解析差分 id → 48×48 AtlasTexture；空串/未登记 id → null（调用方隐藏头像窗）
static func get_texture(portrait_id: String) -> Texture2D:
	if portrait_id.is_empty() or not PORTRAIT_REGIONS.has(portrait_id):
		return null
	var cell: Array = PORTRAIT_REGIONS[portrait_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = FACE_SHEET
	atlas.region = Rect2(int(cell[0]) * CELL_SIZE, int(FACE_ROW_Y[int(cell[1])]), CELL_SIZE, CELL_SIZE)
	return atlas
