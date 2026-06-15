# 探索：执行动作 -> 授予钥匙，返回 {key, text}；未知动作返回空字典。
extends RefCounted

const Content = preload("res://game/content.gd")

static func perform(state, action_id: String) -> Dictionary:
	for a in Content.EXPLORE_ACTIONS:
		if a["id"] == action_id:
			state.add_key(a["grants_key"])
			return {"key": a["grants_key"], "text": a["text"]}
	return {}
