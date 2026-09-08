extends RefCounted
## map_lighting.gd —— M7-A1 地图光照装配器（2.5D 视觉升级 A 路线 · A1 档）
##
## 【职责边界】纯装配、config 字典驱动（TeleportAssembler 同款静态工厂风格）：
##   把 town 的 LIGHTING_CONFIG 变成 CanvasModulate + PointLight2D 节点树。
##   行为只有一处：flicker 光的 energy 呼吸（Tween 循环，随容器销毁自然释放，
##   零全局状态）。范围红线：仅 town 接线；遗迹/road 不动；零新图片资产
##   （光斑纹理 = GradientTexture2D 代码生成，径向 白→透明，256×256）。
##
## 【config 结构】（town 正本 = town_map.gd LIGHTING_CONFIG）：
##   tint:         { "color": Color }                          —— 全图色调压
##   lights: [ { "id": String, "position": Vector2(像素),
##               "color": Color, "energy": float,
##               "range_tiles": float,            # 光斑半径（格数）
##               "flicker": bool(可选) } ]                     —— 静态光源表
##   flicker:      { "enabled": bool, "base": float, "period": float }
##                 —— 呼吸开关与深度（energy 摆动区间 [base,1.0]×配置值）
##   player_light: { "color": Color, "energy": float, "range_tiles": float }
##                 —— 玩家随身光（运行时挂 player，不改 player.tscn）
##
## 【几何口径】range_tiles 为光斑半径（tile 数），纹理覆盖直径 = 半径×2×16px，
##   映射到 256px 纹理 → texture_scale = range_tiles*32/256 = range_tiles/8。
##   例：range_tiles=5 → scale 0.625 → 覆盖 160px（10 tile 直径）。
##
## 【约束】无 class_name（项目纪律：headless 跨脚本 class_name 解析陷阱，
##   同 TeleportAssembler / battle_background 等全部既有装配器；引用方用
##   preload 常量）。全部节点 shadow_enabled=false（16px tile 阴影开销大
##   且易闪，A1 不开）。室内/室外不做区分（A1 范围，主图共用同一 Tint）。

const CONTAINER_NAME := "Lighting"     # 装配容器名（挂地图根，y_sort 之外）
const TINT_NODE_NAME := "Tint"         # CanvasModulate 节点名
const LIGHTS_NODE_NAME := "Lights"     # 静态光源容器名
const LIGHT_TEX_SIZE := 256            # 光斑纹理边长（px）
const CARRY_LIGHT_NAME := "CarryLight" # 玩家随身光节点名


## 装配一张图的光照层。
## p_map：地图根（Node2D，容器挂其下，与 TileMapLayer 平级）；
## p_config：结构见文件头注；p_player：玩家节点（null 则跳过随身光）。
## 返回 Lighting 容器（测试对表用）；重复装配时返回既有容器（防 _ready 重入）。
static func assemble(p_map: Node2D, p_config: Dictionary, p_player: Node2D = null) -> Node2D:
	var existing: Node2D = p_map.get_node_or_null(NodePath(CONTAINER_NAME)) as Node2D
	if existing != null:
		print("[MapLighting] %s 已有光照层，复用既有容器（防重复装配）" % p_map.name)
		return existing
	var root := Node2D.new()
	root.name = CONTAINER_NAME
	# y_sort 之外：不参与遮挡排序；z_index 拉高只影响与 TileMapLayer 的叠放序
	# （PointLight2D 为 add blend，叠放次序不影响光照结果，仅求树面整洁）
	root.y_sort_enabled = false
	root.z_index = 100
	# ① 全图色调压（CanvasModulate；缺 tint 键 = 不压色）
	var tint_cfg: Dictionary = p_config.get("tint", {})
	if tint_cfg.has("color"):
		var tint := CanvasModulate.new()
		tint.name = TINT_NODE_NAME
		tint.color = tint_cfg["color"]
		root.add_child(tint)
	# ② 静态光源体系（光斑纹理共享一份：Resource 只读共享安全，省内存）
	var lights := Node2D.new()
	lights.name = LIGHTS_NODE_NAME
	root.add_child(lights)
	var tex := _make_light_texture()
	var specs: Array = p_config.get("lights", [])
	var flicker_count := 0
	for spec: Dictionary in specs:
		var light := PointLight2D.new()
		light.name = String(spec.get("id", "Light"))
		light.texture = tex
		light.position = spec["position"]
		light.color = spec.get("color", Color.WHITE)
		light.energy = float(spec.get("energy", 1.0))
		light.texture_scale = _range_to_scale(float(spec.get("range_tiles", 4.0)))
		light.shadow_enabled = false
		if bool(spec.get("flicker", false)):
			light.set_meta("flicker", true)
			flicker_count += 1
		lights.add_child(light)
	# ③ 帧动画光（壁炉/烛光呼吸；config 总开关，可整体关停）
	var anim_cfg: Dictionary = p_config.get("flicker", {})
	if flicker_count > 0 and bool(anim_cfg.get("enabled", true)):
		_setup_flicker(lights, anim_cfg)
	# ④ 玩家随身光（运行时挂 player 子节点；player 缺失（测试替身等）跳过）
	if p_player != null and is_instance_valid(p_player):
		p_player.add_child(_make_player_light(p_config.get("player_light", {}), tex))
	p_map.add_child(root)
	print("[MapLighting] %s 光照装配完成：Tint=%s + 静态光 %d 处（呼吸 %d）+ 随身光=%s" % [
			p_map.name, "有" if tint_cfg.has("color") else "无",
			specs.size(), flicker_count,
			"有" if p_player != null else "无（player 缺失跳过）"])
	return root


## 程序化光斑纹理：径向渐变 白(α1)→透明，中心亮边缘衰减。
## fill_from = 纹理中心，fill_to = 顶边中点 → 半径 = 半边长（内切圆满幅）。
static func _make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = LIGHT_TEX_SIZE
	tex.height = LIGHT_TEX_SIZE
	return tex


## range_tiles（半径格数）→ texture_scale（直径像素 / 纹理边长）。
static func _range_to_scale(p_range_tiles: float) -> float:
	return p_range_tiles * 2.0 * 16.0 / float(LIGHT_TEX_SIZE)


## 玩家随身光：小范围暖白跟随光（"提灯"基底），压暗后角色始终可读。
static func _make_player_light(p_cfg: Dictionary, p_tex: Texture2D) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = CARRY_LIGHT_NAME
	light.texture = p_tex
	light.color = p_cfg.get("color", Color(1.0, 0.95, 0.85))
	light.energy = float(p_cfg.get("energy", 0.5))
	light.texture_scale = _range_to_scale(float(p_cfg.get("range_tiles", 4.0)))
	light.shadow_enabled = false
	return light


## 呼吸光：对带 flicker 标记的光源各起一条循环 Tween（正弦缓动，
## energy 在 [base,1.0]×配置值 间往返）。Tween 绑定光源节点自身，
## 图销毁时随树释放，零全局状态、零 _process 常驻。
static func _setup_flicker(p_lights: Node2D, p_cfg: Dictionary) -> void:
	var base := float(p_cfg.get("base", 0.85))
	var period := float(p_cfg.get("period", 0.9))
	for light: PointLight2D in p_lights.get_children():
		if not bool(light.get_meta("flicker", false)):
			continue
		var target := light.energy * base
		var tw := light.create_tween()
		tw.set_loops()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(light, "energy", target, period * 0.5)
		tw.tween_property(light, "energy", light.energy, period * 0.5)
