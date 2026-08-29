extends Resource
## CharacterRecord —— 队伍角色运行时数值记录（E2-S1，ADR-2 数值口径）
##
## 定位：战斗 GDD §5 角色表在"运行时态"的最小投影——只存当前值，
## 静态上限/成长等整表数据属内容 JSON 表（characters 表，EPIC-2 后续
## Story 接入），本类不重复承载。
##
## 引用方式：preload 常量（const CharacterRecord := preload(...)）。
## 刻意不用全局 class_name：headless -s 跑测通道不重扫全局类注册表，
## 新增全局类需编辑器导入通道刷新缓存——本环境该通道不稳定，
## preload 引用在任何通道下都即时可用，且类型检查能力完全等价。
##
## 说明：
##   - max_hp/max_mp 为运行时冗余字段：UI（调试面板/战斗血条）需要上限
##     画条，从等级反查上限表属于额外查询链，切片阶段直接冗余存储
##     （升级时由成长模块一并覆写，本类自身不做成长计算）；
##   - 纯数据类：零函数（除构造器）、零信号、零 IO——GameData 的 A3
##     职责边界对成员数据类同样生效；
##   - 独立文件而非内嵌类：game_data.gd 作为 Autoload 只保留字段声明，
##     结构化数值类型（ADR-2）归 core 层，供战斗/存档/调试面板共同引用。

## 角色稳定 id（内容表主键，如 "kyle"；运行时数据与内容表的对账键）
@export var id: String = ""
## 显示名（调试面板/战斗 UI 直读）
@export var name: String = ""
## 职业标识（"swordsman"剑士 / "sorcerer"术士 / "support"辅助）
@export var job: String = ""
## 当前等级
@export var level: int = 1
## 当前 HP
@export var hp: int = 1
## 当前 HP 上限
@export var max_hp: int = 1
## 当前 MP
@export var mp: int = 1
## 当前 MP 上限
@export var max_mp: int = 1


## 便捷构造器（字段全量传入，避免逐属性赋值的样板代码）
func _init(p_id: String = "", p_name: String = "", p_job: String = "",
		p_level: int = 1, p_hp: int = 1, p_max_hp: int = 1,
		p_mp: int = 1, p_max_mp: int = 1) -> void:
	id = p_id
	name = p_name
	job = p_job
	level = p_level
	hp = p_hp
	max_hp = p_max_hp
	mp = p_mp
	max_mp = p_max_mp
