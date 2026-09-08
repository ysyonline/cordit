extends RefCounted
## char_anim.gd —— Antifarea charset 动画资源工厂（R2-CHARSPRITE）
##
## 【需求依据】R2-CHARSPRITE：player/npc 换装。帧网实测正本
##   assets/characters/charset_frames.md（男带 y=180 / 女带 y=306，块
##   x=16+48c，每块 48x72 = 16x18 × 3帧×4向；行序 up/left/down/right，
##   帧序 walkA/idle/walkB——中间帧即静止帧）。
##
## 【设计裁决】全项目共享 1 份 SpriteFrames 资源（8 动画，帧为 AtlasTexture
##   指向 5 张整图之一）+ 按 (charset_id, facing) 运行时切帧——避免 14 个
##   NPC 各复制一份帧纹理；SpriteFrames 进程内单例缓存，玩家与 NPC 共用。
##
## 【层位纪律】core 静态工具：无状态副作用、不进树、零热路径分配
##   （缓存命中路径只做 Dictionary 查询）。
##
## 【边界】不感知 gameplay；对外只暴露 get_frames() / region_of()。

## 图集纹理（R4 透明转写件 + R5 调色板变体；R1 提亮件无 alpha 禁用）
const SHEET_MAIN: String = "res://assets/characters/charsets_12_m-f_antifarea_bright_alpha.png"
const SHEET_V1_ELDER: String = "res://assets/characters/charsets_12_m-f_antifarea_bright_alpha_v1_elder.png"
const SHEET_V2_PORTER: String = "res://assets/characters/charsets_12_m-f_antifarea_bright_alpha_v2_porter.png"
const SHEET_V3_SMITH: String = "res://assets/characters/charsets_12_m-f_antifarea_bright_alpha_v3_smith.png"
const SHEET_V4_SHEPHERD: String = "res://assets/characters/charsets_12_m-f_antifarea_bright_alpha_v4_shepherd.png"

## 单帧尺寸（px，帧网实测）
const FRAME_W: int = 16
const FRAME_H: int = 18

## walk 动画帧率（charset_frames.md §7：72px/s 两步一循环 0.5s）
const WALK_FPS: float = 8.0

## 朝向 → 行号（charset_frames.md §5）
const FACING_ROW: Dictionary = {
	"up": 0, "left": 1, "down": 2, "right": 3,
}

## 形象 id → 图集路径（V1..V4 为调色板变体，其余共享主图）
const SHEET_BY_ID: Dictionary = {
	"m1": SHEET_MAIN, "m2": SHEET_MAIN, "m3": SHEET_MAIN,
	"m4": SHEET_MAIN, "m5": SHEET_MAIN, "m6": SHEET_MAIN,
	"f1": SHEET_MAIN, "f2": SHEET_MAIN, "f3": SHEET_MAIN,
	"f4": SHEET_MAIN, "f5": SHEET_MAIN, "f6": SHEET_MAIN,
	"v1_elder": SHEET_V1_ELDER,
	"v2_porter": SHEET_V2_PORTER,
	"v3_smith": SHEET_V3_SMITH,
	"v4_shepherd": SHEET_V4_SHEPHERD,
}

## 8 动画名（每向 idle_<dir> 单帧 + walk_<dir> 4 拍）
const ANIM_NAMES: Array[String] = [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
]

## SpriteFrames 进程内缓存（RefCounted 单例语义：同帧网全树共享）
static var _cached: SpriteFrames = null


## 形象 id → 块原点（charset_frames.md §3/§4；未知 id 返回 null）
static func block_origin(charset_id: String) -> Variant:
	var sheet_row: int = 0
	var col: int = -1
	if charset_id.begins_with("m"):
		col = int(charset_id.substr(1)) - 1
	elif charset_id.begins_with("f"):
		col = int(charset_id.substr(1)) - 1
		sheet_row = 1
	elif charset_id == "v1_elder":       # 基于 F6
		col = 5
		sheet_row = 1
	elif charset_id == "v2_porter":      # 基于 M1
		col = 0
		sheet_row = 0
	elif charset_id == "v3_smith":       # 基于 M2
		col = 1
		sheet_row = 0
	elif charset_id == "v4_shepherd":    # 基于 F2
		col = 1
		sheet_row = 1
	else:
		return null
	var y0: int = 180 if sheet_row == 0 else 306
	return Vector2i(16 + col * 48, y0)


## (形象 id, 朝向, 帧列) → 图集区域 Rect2（帧网公式，charset_frames.md §5）
static func region_of(charset_id: String, facing: String, frame_col: int) -> Rect2:
	var origin: Vector2i = block_origin(charset_id)
	var row: int = int(FACING_ROW.get(facing, 2))   # 未知朝向兜底 down
	return Rect2(origin.x + frame_col * FRAME_W, origin.y + row * FRAME_H, FRAME_W, FRAME_H)


## 共享 SpriteFrames（8 动画；首调构建，后续零分配返回缓存）。
## 各动画内帧的 AtlasTexture 均指向【主图】M1 块的对应格位置——动画名相同
## 的帧结构对 16 个形象完全一致，切形象时按 region_of() 换 region 即可，
## SpriteFrames 全树一份。
static func get_frames() -> SpriteFrames:
	if _cached != null:
		return _cached
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var sheet: Texture2D = load(SHEET_MAIN)
	var origin: Vector2i = block_origin("m1")
	for dir: String in ["down", "up", "left", "right"]:
		var row: int = int(FACING_ROW[dir])
		var idle_name := "idle_" + dir
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, _atlas(sheet, origin, row, 1))
		var walk_name := "walk_" + dir
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, WALK_FPS)
		frames.set_animation_loop(walk_name, true)
		# 4 拍循环：walkA → idle → walkB → idle（帧网 §5）
		for col: int in [0, 1, 2, 1]:
			frames.add_frame(walk_name, _atlas(sheet, origin, row, col))
	_cached = frames
	return frames


## 形象 id → 该形象 idle_down 帧的 AtlasTexture（NPC 静态朝向直取）
static func get_idle_texture(charset_id: String, facing: String = "down") -> AtlasTexture:
	var sheet: Texture2D = load(String(SHEET_BY_ID.get(charset_id, SHEET_MAIN)))
	return _atlas(sheet, block_origin(charset_id), int(FACING_ROW.get(facing, 2)), 1)


## AtlasTexture 构造（帧网公式单点）
static func _atlas(sheet: Texture2D, origin: Vector2i, row: int, col: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(origin.x + col * FRAME_W, origin.y + row * FRAME_H, FRAME_W, FRAME_H)
	return atlas
