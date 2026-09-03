extends Node
## probe_on_interact —— Group G 分派链探针（E5-M5 测试夹具）
##
## 纯自治协议实体：只实现 on_interact()，不带 get_npc_id——固化
## interaction_controller._try_interact 的分派契约：
##   自治协议（on_interact）第一优先；无自治协议才退回 get_npc_id 路径。
## Boss 事件壳（trigger_event_shell）即此类纯自治实体。

var fired: int = 0


func on_interact() -> void:
	fired += 1
	print("[ProbeOnInteract] on_interact 触发（第 %d 次）" % fired)
