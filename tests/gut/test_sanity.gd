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
