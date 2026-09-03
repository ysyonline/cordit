extends GutTest
## GUT 落地自检（TASK-S2-01）——最小示例，验证 GUT 9.7.1 在 Godot 4.7.2 headless 下可工作
##
## 断言三件事：
##   1. 框架自身可用（1 + 1 == 2）；
##   2. 四 Autoload 注册生效（SMK-01 同源校验的简化版）；
##   3. EventBus 单例可访问且为 Node。
##
## 跑法（项目根下）：
##   Godot_console.exe --headless --path . -s -gdir=res://tests/gut -ginclude_subdirs -gexit

func test_sanity_框架可用_一加一等于二() -> void:
	assert_eq(1 + 1, 2, "GUT 基本断言可用")


func test_sanity_四_autoload_可访问() -> void:
	# 与 SMK-01 同源：四个 Autoload 单例在 GUT 环境下可直接访问
	assert_not_null(GameData, "GameData 应存在")
	assert_not_null(EventBus, "EventBus 应存在")
	assert_not_null(SceneRouter, "SceneRouter 应存在")
	assert_not_null(SaveManager, "SaveManager 应存在")


func test_sanity_事件总线是节点() -> void:
	# EventBus 是 Autoload Node，且继承链正确（类型标注校验，ADR-1 精神）
	assert_true(EventBus is Node, "EventBus 应为 Node")


func test_sanity_所有测试脚本都能被GUT收集() -> void:
	# 【为什么需要这条】
	#   GUT 遇到"存在解析错误"或"未继承 GutTest"的测试脚本时，只打一条
	#   WARNING 就跳过整个文件，Run Summary 依然报 "All tests passed"。
	#   即：一个坏掉的测试文件会【静默】从测试集里消失，回归防线当场开个洞，
	#   而跑测结论仍然是绿的。
	#   E3-S2 施工时真实踩到一次——test_e3s2.gd 因函数名含非法字符 % 导致
	#   解析失败，整份 56 条用例被静默跳过，而当时跑测全绿、退出码 0。
	#
	# 【做法】逐个 load 并实例化，断言继承 GutTest：
	#   解析失败在这里会变成显式 FAIL，而不是一条没人看的 WARNING。
	var dir: DirAccess = DirAccess.open("res://tests/gut")
	assert_not_null(dir, "应能打开 res://tests/gut")
	var checked: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var path: String = "res://tests/gut/%s" % file
		var script: GDScript = load(path) as GDScript
		assert_not_null(script,
				"测试脚本应能加载（解析失败会被 GUT 静默跳过）：%s" % path)
		if script == null:
			continue
		var instance: Variant = script.new()
		assert_true(instance is GutTest,
				"测试脚本应继承 GutTest（否则 GUT 不收集）：%s" % path)
		# 手动实例化不入场景树，用完即释放（GutTest 为 Node 或 RefCounted 皆兼容）
		if instance is Node:
			(instance as Node).free()
		elif instance is RefCounted:
			(instance as RefCounted).free()
		checked += 1
	assert_gte(checked, 11, "扫描到的测试脚本数应不少于既有数量（新增脚本请同步更新此哨兵值）")
