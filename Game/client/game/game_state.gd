# 游戏状态：持有的钥匙、已揭示的真相、对话历史。
extends RefCounted

const Content = preload("res://game/content.gd")

var keys := {}        # {key: true}
var revealed := {}    # {truth_id: true}
var history: Array = []  # [{role, content}]

# 莫忘 AI 助手提醒（由模型在对话中触发；同一提醒整局只触发一次）
var hints_fired := {}    # {hint_id: true} 已触发过的提醒，用于去重
var mowang_log: Array = []  # 已触发的提醒文案，按顺序（莫忘 app 里展示）
var mowang_unread := false  # 有新提醒未读 → 手机/莫忘 app 亮红点

# 上司任务：开局即有一条未读（手机/任务 app 亮红点，引导玩家先看任务）
var task_unread := true

# 道具栏：拿到的实物道具（钥匙、老人的手机…），跨场景保留，门禁判定 + 道具栏展示用
var items := {}    # {item_id: true}

var presented := {}   # {card_id: true} 已当面出示过的证据牌
var evidence_seen := {}   # 已弹过"获得证据"toast 的卡 id，去重(随新游戏=新 GameState 自动重置)
var evidence_howto_shown := false   # 是否已弹过"可点证据牌出示给老头"的一次性操作提醒
var phone_line_unlocked := false   # 隐藏电话线：玩家问过"他为什么打电话"后解锁；随新游戏=新 GameState 重置
var terminal_chat: Array = []   # 终端查询机的聊天记录 [{who,msg}…]，跨场景保留(离开终端室再回来仍在)；随新游戏重置

# 终端聊天追加一条(查询机每问/每答各一条)，离开终端室再回来时据此重渲染。
func add_terminal_chat(who: String, msg: String) -> void:
	terminal_chat.append({"who": who, "msg": msg})

func add_item(id: String) -> void:
	items[id] = true

func has_item(id: String) -> bool:
	return items.has(id)

func present_evidence(id: String) -> void:
	if id != "":
		presented[id] = true

# 已出示证据拼成【系统旁白】（玩家不可见）发给模型；未出示的不告诉老头。
func presented_proofs() -> String:
	var lines := []
	for c in Content.EVIDENCE_CARDS:
		if c["id"] in presented:
			lines.append(str(c["proof"]))
	if lines.is_empty():
		return ""
	return "【系统旁白·仅你(周明远扮演者)可知，玩家看不到】侦探此刻已经把这些摆到你面前：" + "；".join(lines) + "。这些是他真的拿出来、你正看着的东西；没在这上面的，你当他没有、也不知道他有。"

# 首次见该证据 → true(该弹 toast)；已弹过或空 → false。
func mark_evidence_seen(card_id: String) -> bool:
	if card_id == "" or evidence_seen.has(card_id):
		return false
	evidence_seen[card_id] = true
	return true

# 进审讯室、手里第一次有证据时调：首次 → true(该弹"可出示证据"提醒)，之后 → false(只提醒一次)。
func mark_evidence_howto() -> bool:
	if evidence_howto_shown:
		return false
	evidence_howto_shown = true
	return true

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

# 是否进入终局对峙：拿到莫忘日志(molog)即视为已掌握全部真相。
# 终局时客户端发 finale=true 给后端切换系统提示(见 interrogation._send)，旁白不再客户端注入。
func in_finale() -> bool:
	return has_key("molog")
