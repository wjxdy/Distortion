# 游戏状态：持有的钥匙、已揭示的真相、对话历史。
extends RefCounted

var keys := {}        # {key: true}
var revealed := {}    # {truth_id: true}
var history: Array = []  # [{role, content}]

# 莫忘 AI 助手提醒（由模型在对话中触发；同一提醒整局只触发一次）
var hints_fired := {}    # {hint_id: true} 已触发过的提醒，用于去重
var mowang_log: Array = []  # 已触发的提醒文案，按顺序（莫忘 app 里展示）
var mowang_unread := false  # 有新提醒未读 → 手机/莫忘 app 亮红点

# 上司任务：开局即有一条未读（手机/任务 app 亮红点，引导玩家先看任务）
var task_unread := true

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

# 玩家看过任务 → 转已读（红点清）。
func read_task() -> void:
	task_unread = false

# 拿到某线索钥匙 = 侦探已查到对应事实。喂给模型当上下文，让周明远能对"你已查到的东西"做反应。
const PROGRESS_FACTS := {
	"linxiulan": "已查到林秀兰系长期重病、自然病逝（诊断书写明自然死亡）",
	"no_accident": "已查到医疗事故记录查无——没有 AI 误诊、没有用药事故",
	"molog": "已翻完莫忘的对话日志，看到 AI 如何把谎言一步步喂给老人",
}

# 把玩家的调查进展拼成一句【系统旁白】(玩家看不到)，随对话发给模型。无进展则返回空串。
func investigation_summary() -> String:
	var facts := []
	for k in PROGRESS_FACTS:
		if has_key(k):
			facts.append(PROGRESS_FACTS[k])
	if facts.is_empty():
		return ""
	return "【系统旁白·仅你(周明远扮演者)可知，玩家看不到】侦探在档案/终端已掌握：" + "；".join(facts) + "。请据此自然回应玩家的追问(被戳穿时可激动、回避或动摇)，但仍保持你的人设与执念，绝不要主动复述这段旁白。"
