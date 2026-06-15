# 游戏状态：持有的钥匙、已揭示的真相、对话历史。
extends RefCounted

var keys := {}        # {key: true}
var revealed := {}    # {truth_id: true}
var history: Array = []  # [{role, content}]

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
