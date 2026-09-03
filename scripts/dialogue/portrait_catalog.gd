extends RefCounted
## portrait_catalog.gd —— 对话头像差分目录（E5-S1，对话 GDD §3.1/§4）
##
## 【需求依据】对话 GDD §3.1 字段表：portrait = 头像差分 id（如 kai_normal /
##   rina_smile），缺省沿用上一条；§4：头像窗（左侧，差分切换）——头像差分
##   用静态贴图换帧，不做立绘动画。UI 规格 §二/§四表 9 行：CharlesGabriel
##   48×48 Faces 原生 48×48 零缩放显示（64×64 旧口径已废弃，禁——48→64 为
##   非整数放大，会糊）。
##
## 【为什么是静态目录】切片内头像差分 ≈ 3 主角 × 3-4 态；一张区块表 + 纯函数
##   解析即可（ADR-2 精神：内容数据与解析分离，改表不改运行时）。美术线
##   R2/R3 正式排位到位后只需替换 PORTRAIT_REGIONS 表，换帧机制与 48×48
##   尺寸契约不受影响。
##
## 【占位映射声明】faces 集散图为 48×48 网格（288×400 = 6 列 × 8 行整 +
##   16px 残带，残带不取）。角色→列、差分→行目前为工程占位：
##   col0=凯尔（kai/kyle 双 id 兼容，GDD 示例用 kai_*，战斗数据 id 为 kyle）、
##   col1=莉娜（rina）、col2=莫娜（mona）；r0=normal / r1=smile / r2=angry /
##   r3=hurt。正式排位待美术 intake 登记（assets/CREDITS.md 流程）后换表。
##
## 【边界】纯静态工具：无状态、无节点依赖（scripts/core 纪律同款）。
##   未知 id / 空串返回 null——对话框隐藏头像窗（优雅降级：NPC 文案暂缺
##   portrait 字段、或未登记 NPC 差分时不报错）。

## 头像集散图（48×48 Faces 1st Sheet，CC-BY 3.0，授权见 assets/licenses/notices/48x48-faces.txt）
const FACE_SHEET: Texture2D = preload("res://assets/faces/48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png")

## 单格边长（原生 48×48；UI 规格冻结口径，禁 64×64 非整数放大）
const CELL_SIZE: int = 48

## 差分 id → 集散图区块 [col, row]（0 起；行 8 残带不登记）
const PORTRAIT_REGIONS: Dictionary = {
	"kai_normal": [0, 0], "kai_smile": [0, 1], "kai_angry": [0, 2], "kai_hurt": [0, 3],
	"kyle_normal": [0, 0], "kyle_smile": [0, 1], "kyle_angry": [0, 2], "kyle_hurt": [0, 3],
	"rina_normal": [1, 0], "rina_smile": [1, 1], "rina_angry": [1, 2], "rina_hurt": [1, 3],
	"mona_normal": [2, 0], "mona_smile": [2, 1], "mona_angry": [2, 2], "mona_hurt": [2, 3],
}

## 解析差分 id → 48×48 AtlasTexture；空串/未登记 id → null（调用方隐藏头像窗）
static func get_texture(portrait_id: String) -> Texture2D:
	if portrait_id.is_empty() or not PORTRAIT_REGIONS.has(portrait_id):
		return null
	var cell: Array = PORTRAIT_REGIONS[portrait_id]
	var atlas := AtlasTexture.new()
	atlas.atlas = FACE_SHEET
	atlas.region = Rect2(int(cell[0]) * CELL_SIZE, int(cell[1]) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	return atlas
