# 确定性钩子判定：持有 required_key + 玩家发言命中关键词 + 未揭示过 -> 触发该真相。
extends RefCounted

const Content = preload("res://game/content.gd")

static func evaluate(state, message: String) -> Array:
	var triggered := []
	for t in Content.TRUTHS:
		if state.is_revealed(t["id"]):
			continue
		if not state.has_key(t["required_key"]):
			continue
		for kw in t["keywords"]:
			if kw in message:
				triggered.append(t["id"])
				break
	return triggered

static func fragment_of(id: String) -> String:
	for t in Content.TRUTHS:
		if t["id"] == id:
			return t["fragment"]
	return ""
