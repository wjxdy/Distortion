# 游戏状态：持有的钥匙、已揭示的真相、对话历史。
extends RefCounted

var keys := {}        # {key: true}
var revealed := {}    # {truth_id: true}
var history: Array = []  # [{role, content}]

# 莫忘 AI 助手提醒（由模型在对话中触发；同一提醒整局只触发一次）
var hints_fired := {}    # {hint_id: true} 已触发过的提醒，用于去重
var mowang_log: Array = []  # 已触发的提醒文案，按顺序（莫忘 app 里展示）
var mowang_unread := false  # 有新提醒未读 → 手机/莫忘 app 亮红点

func add_key(k: String) -> void:
	keys[k] = true

func has_key(k: String) -> bool:
	return keys.has(k)

func reveal(id: String) -> void:
	revealed[id] = true

func is_revealed(id: String) -> bool:
	return revealed.has(id)

func add_to_history(role: String, content: String) -> void:
	history.append({"role": role, "content": content})

# 触发一条莫忘提醒：新提醒记入日志并标未读，返回 true；已触发过(或空ID)返回 false（去重）。
func fire_hint(id: String, text: String) -> bool:
	if id == "" or hints_fired.has(id):
		return false
	hints_fired[id] = true
	mowang_log.append(text)
	mowang_unread = true
	return true

# 玩家看过莫忘 app → 转已读（红点清）。
func read_mowang() -> void:
	mowang_unread = false
