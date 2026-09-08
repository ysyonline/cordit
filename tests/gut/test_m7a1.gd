extends GutTest
## M7-A1 town 光照层测试（2.5D 视觉升级 A 路线 · A1 档）
##
## 【被测】scripts/maps/map_lighting.gd（静态装配器）+
##   town_map.gd LIGHTING_CONFIG / _assemble_lighting 接线。
##
## 【跑法】项目根下（MSYS2 Git Bash，干净 APPDATA 防 e5s5 d1 污染）：
##   MSYS2_ARG_CONV_EXCL="*" APPDATA="<干净APPDATA>" \
##   Godot_console.exe --headless --path . -s addons/gut/gut_cmdln.gd \
##     -gtest=res://tests/gut/test_m7a1.gd -gexit
##
## 【分组】
##   A 装配结构：Lighting 容器 + Tint 色值 + Lights 数量 + 随身光在位
##   B 光源对表：逐光源 texture/shadow/位置/颜色/能量/范围（配置表驱动，
##     加灯自动扩展断言）+ 坐标口径哨兵 + flicker 标记 + 幂等复用
##
## 【纪律】净增不改旧：本文件只新增，不触碰任何既有测试；town 直挂
## （_load_town 同 test_m7r6 口径），不依赖 Main 结构与 user:// 存档。

const TOWN_SCENE: String = "res://scenes/maps/town.tscn"
const MapLighting := preload("res://scripts/maps/map_lighting.gd")


## town.tscn 实树装配（test_m7r6 _load_town 同口径：_ready 全链直挂）
func _load_town() -> Node:
	var packed: PackedScene = load(TOWN_SCENE)
	var map: Node = packed.instantiate()
	add_child_autofree(map)
	return map


## Lighting 容器快捷取用
func _lighting_of(map: Node) -> Node2D:
	return map.get_node_or_null("Lighting") as Node2D


# ------------------------------------------------------------------
# Group A —— 装配结构
# ------------------------------------------------------------------

func test_a1_town挂载后存在Lighting容器与Tint() -> void:
	var map: Node = _load_town()
	var root: Node2D = _lighting_of(map)
	assert_true(root != null, "town 应存在 Lighting 容器（_assemble_lighting 产物）")
	if root == null:
		return
	var tint: CanvasModulate = root.get_node_or_null("Tint") as CanvasModulate
	assert_true(tint != null, "Lighting 下应存在 Tint（CanvasModulate）")
	var want: Color = map.LIGHTING_CONFIG["tint"]["color"]
	assert_eq(tint.color, want, "Tint 色值应与 LIGHTING_CONFIG 配置一致（白天暖调）")


func test_a2_Lights子节点数等于配置光源数() -> void:
	var map: Node = _load_town()
	var root: Node2D = _lighting_of(map)
	var lights: Node2D = root.get_node("Lights") as Node2D
	var want: int = (map.LIGHTING_CONFIG["lights"] as Array).size()
	assert_eq(lights.get_child_count(), want, "Lights 子节点数应与配置光源数一致")
	assert_eq(want, 7, "配置口径哨兵：M7-A1 town 静态光源 7 处（改表须同步改哨兵）")


func test_a3_玩家随身光在位() -> void:
	var map: Node = _load_town()
	var player: Node2D = map.get_node("YSorted/Player") as Node2D
	assert_true(player != null, "town 应有 YSorted/Player（装配前置）")
	var carry: PointLight2D = player.get_node_or_null("CarryLight") as PointLight2D
	assert_true(carry != null, "player 下应存在随身光 CarryLight（运行时挂，tscn 零改动）")
	if carry == null:
		return
	assert_true(carry.texture != null, "随身光 texture 应非空（GradientTexture2D）")
	assert_true(carry.texture is GradientTexture2D, "随身光纹理应为代码生成 GradientTexture2D")
	assert_false(carry.shadow_enabled, "随身光 shadow 应关闭（A1 口径）")
	var pcfg: Dictionary = map.LIGHTING_CONFIG["player_light"]
	# energy/scale 断言用 almost_eq：light.energy 为 32 位 float 回读（0.5/0.8 存储有微差）
	assert_almost_eq(carry.energy, float(pcfg["energy"]), 0.001, "随身光 energy 应与配置一致")
	assert_eq(carry.color, pcfg["color"], "随身光颜色应与配置一致")


# ------------------------------------------------------------------
# Group B —— 光源逐项对表（配置表驱动）
# ------------------------------------------------------------------

func test_b1_静态光源逐项与配置表一致() -> void:
	var map: Node = _load_town()
	var root: Node2D = _lighting_of(map)
	var lights: Node2D = root.get_node("Lights") as Node2D
	var specs: Array = map.LIGHTING_CONFIG["lights"] as Array
	assert_eq(lights.get_child_count(), specs.size(), "光源数与配置一致（对表前置）")
	for spec: Dictionary in specs:
		var light: PointLight2D = lights.get_node_or_null(String(spec["id"])) as PointLight2D
		assert_true(light != null, "光源 %s 应存在且为 PointLight2D" % spec["id"])
		if light == null:
			continue
		assert_true(light.texture != null, "%s texture 应非空（GradientTexture2D 代码生成）" % spec["id"])
		assert_true(light.texture is GradientTexture2D, "%s 纹理应为 GradientTexture2D（零新素材口径）" % spec["id"])
		assert_false(light.shadow_enabled, "%s shadow 应关闭（16px tile 阴影不开）" % spec["id"])
		assert_eq(light.position, spec["position"], "%s 像素坐标应与配置一致" % spec["id"])
		assert_eq(light.color, spec["color"], "%s 颜色应与配置一致" % spec["id"])
		assert_almost_eq(light.energy, float(spec["energy"]), 0.001,
				"%s energy 应与配置一致（32 位 float 回读容差）" % spec["id"])
		var want_scale: float = float(spec["range_tiles"]) * 2.0 * 16.0 / 256.0
		assert_almost_eq(light.texture_scale, want_scale, 0.0001,
				"%s texture_scale 应对应 range_tiles=%s（半径格数→直径映射）" % [spec["id"], spec["range_tiles"]])


func test_b2_光源位置像素坐标口径() -> void:
	# tile*16+8 口径哨兵：抽验三处派单坐标（喷泉/炉火/南门）
	var map: Node = _load_town()
	var lights: Node2D = (_lighting_of(map)).get_node("Lights") as Node2D
	assert_eq((lights.get_node("FountainWater") as PointLight2D).position, Vector2(448, 448),
			"喷泉 2×2 中心 = tile(27..28,27..28)×16+8 → (448,448)")
	assert_eq((lights.get_node("InnFireplace") as PointLight2D).position, Vector2(1304, 200),
			"室内A壁炉 tile(81,12) → (1304,200)")
	assert_eq((lights.get_node("SouthGateLamp") as PointLight2D).position, Vector2(208, 744),
			"南门口 tile(12.5,46.5) → (208,744)")


func test_b3_呼吸光标记与容器归属() -> void:
	# flicker 光（炉火/喷泉/烛光）应有 flicker meta；容器在图根下（y_sort 之外）
	var map: Node = _load_town()
	var root: Node2D = _lighting_of(map)
	assert_eq((map.get_node("YSorted") as Node2D).y_sort_enabled, true, "哨兵：YSorted 仍开 y_sort（光照容器应在其外）")
	assert_false(root.y_sort_enabled, "Lighting 容器不参与 y_sort")
	for spec: Dictionary in map.LIGHTING_CONFIG["lights"] as Array:
		var light: PointLight2D = root.get_node("Lights").get_node(String(spec["id"])) as PointLight2D
		assert_eq(bool(light.get_meta("flicker", false)), bool(spec.get("flicker", false)),
				"%s flicker 标记应与配置一致" % spec["id"])


func test_b4_重复装配幂等复用() -> void:
	# 防御口径：_ready 重入不产生第二套光照
	var map: Node = _load_town()
	var first: Node2D = _lighting_of(map)
	var again: Node2D = MapLighting.assemble(map, map.LIGHTING_CONFIG, null)
	assert_eq(again, first, "重复 assemble 应回同一容器（防重复装配）")
	assert_eq(first.get_child_count(), 2, "幂等：Lighting 结构仍为 Tint+Lights 两件（未翻倍）")
	assert_eq((first.get_node("Lights") as Node2D).get_child_count(),
			(map.LIGHTING_CONFIG["lights"] as Array).size(), "幂等：光源数未翻倍")
