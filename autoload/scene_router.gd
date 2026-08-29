extends Node
## SceneRouter —— 场景路由单例（Autoload 注册名：SceneRouter）
##
## 职责边界（架构文档 A3 表）：
##   封装场景切换（change_scene 系 API）+ 过渡遮罩 + 载荷暂存与校验；
##   不知道任何具体场景的内容，只管"切"。
##
## ⚠ E1-S2 空壳：本文件当前只有类壳与占位方法。
##   切换 / 0.2s 淡入淡出 / payload 合法性校验（不合法拒绝并打印原因）
##   全部属于 E1-S3（Main + UILayer + SceneRouter，EPIC-1.md）的实现范围，
##   此处【不提前实现】——占位方法抛错，防止被误调用时静默通过。
##
## 目标结构参考（E1-S3 正式化时对齐架构 A4）：
##   Main（常驻根，scenes/main.tscn）
##   ├── World    ← 当前地图 / 战斗场景由 Router 替换
##   └── UILayer  ← 对话框 / 菜单 / 过渡遮罩，跨场景常驻
##
## 流转契约（E1-S3 实现时遵守，架构 A4/A5）：
##   地图遇敌 → EventBus.enemy_touched(payload) → Router 装载战斗场景
##   战斗结算 → EventBus.battle_finished(result) → Router 装载回地图场景
##   每次切换前先校验 payload，不合法 → 拒绝切换并打印原因（SMK-09/10 验收点）


## 场景切换入口（占位）——E1-S3 实现切换 + 校验 + 过渡遮罩
func change_scene(_path: String, _payload: Dictionary = {}) -> void:
	push_error("SceneRouter.change_scene 尚未实现：E1-S3 落地，勿在空壳阶段调用")


## 载荷校验入口（占位）——E1-S3 实现（对照架构 A5 BattlePayload 字段表）
func validate_payload(_payload: Dictionary) -> bool:
	push_error("SceneRouter.validate_payload 尚未实现：E1-S3 落地")
	return false
