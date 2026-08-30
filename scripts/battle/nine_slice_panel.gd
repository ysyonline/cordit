extends Control

## ADR-4 自制九宫格面板（E3-S4 配套 · 五色板裁决）
##
## 用 9+ 块 ColorRect 拼合：四角固定 8×8、四边按 8px 平铺（禁拉伸）、
## 中心填充一面。整套 UI 不依赖任何美术资源——五色板由调用方注入，
## 保证「9-slice 边条 tile 平铺、绝不拉伸」的硬约束（GDD §4 / ADR-4）。
##
## 测试可断言：margin == 8、patch_count() >= 9（非单一拉伸矩形）。

const MARGIN := 8.0

# 默认五色板（BattleUI 会按自身配色覆盖）
var _c_bg: Color = Color(0.10, 0.11, 0.15)
var _c_face: Color = Color(0.22, 0.24, 0.30)
var _c_edge: Color = Color(0.55, 0.58, 0.68)
var _c_edge_dk: Color = Color(0.33, 0.36, 0.44)
var _c_hi: Color = Color(0.95, 0.85, 0.30)

var _built: bool = false


func configure(bg: Color, face: Color, edge: Color, edge_dk: Color, hi: Color) -> void:
	_c_bg = bg; _c_face = face; _c_edge = edge; _c_edge_dk = edge_dk; _c_hi = hi
	if _built:
		_rebuild()


## 首次构建（幂等）。size 需在调用前设置好。
func build() -> void:
	if _built:
		return
	_rebuild()
	_built = true


func _rebuild() -> void:
	for c in get_children().duplicate():
		c.free()
	# 1) 底色铺满
	var bg := ColorRect.new()
	bg.color = _c_bg
	bg.size = size
	add_child(bg)
	# 2) 中心面板（面）
	var face := ColorRect.new()
	face.color = _c_face
	face.position = Vector2(MARGIN, MARGIN)
	face.size = size - Vector2(MARGIN * 2.0, MARGIN * 2.0)
	add_child(face)
	# 3) 四角（8×8 亮块，中心对齐角点）
	_add_corner(MARGIN, MARGIN)
	_add_corner(size.x - MARGIN, MARGIN)
	_add_corner(MARGIN, size.y - MARGIN)
	_add_corner(size.x - MARGIN, size.y - MARGIN)
	# 4) 四边平铺 8px 段（禁拉伸）
	_tile_h(MARGIN, 0.0, size.x - 2.0 * MARGIN)
	_tile_h(MARGIN, size.y - MARGIN, size.x - 2.0 * MARGIN)
	_tile_v(0.0, MARGIN, size.y - 2.0 * MARGIN)
	_tile_v(size.x - MARGIN, MARGIN, size.y - 2.0 * MARGIN)


func _add_corner(cx: float, cy: float) -> void:
	var r := ColorRect.new()
	r.color = _c_edge
	r.size = Vector2(MARGIN, MARGIN)
	r.position = Vector2(cx - MARGIN / 2.0, cy - MARGIN / 2.0)
	add_child(r)


func _tile_h(x0: float, y: float, w: float) -> void:
	var n: int = ceili(w / MARGIN)
	for i in n:
		var r := ColorRect.new()
		r.color = _c_edge
		r.size = Vector2(MARGIN, MARGIN)
		r.position = Vector2(x0 + float(i) * MARGIN, y - MARGIN / 2.0)
		add_child(r)


func _tile_v(x: float, y0: float, h: float) -> void:
	var n: int = ceili(h / MARGIN)
	for i in n:
		var r := ColorRect.new()
		r.color = _c_edge
		r.size = Vector2(MARGIN, MARGIN)
		r.position = Vector2(x - MARGIN / 2.0, y0 + float(i) * MARGIN)
		add_child(r)


## 测试用：返回装饰子块数量（应 >= 9：底 1 + 面 1 + 角 4 + 边段若干）
func patch_count() -> int:
	return get_child_count()
