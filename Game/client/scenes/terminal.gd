# 警局电脑终端室：玩家先进一个可走房间，走到综合终端机前按 ↑/W 打开查询界面。
# 查询界面改为自然语言聊天查询；关闭后回到房间，门口按 ↑/W 返回警局走廊。
extends Control

const POLICE := "res://scenes/police.tscn"
const Content = preload("res://game/content.gd")
const LLM = preload("res://game/llm.gd")
const PlayerScript = preload("res://scenes/player.gd")

# 查到某案卷 → 莫忘弹一条提醒引导回去问老头(确定性双向提示)
const FILE_HINTS := {
	"wife": "ask_wife_death",
	"medical": "ask_farewell",
	"address": "got_address",
}

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var terminal_area: Area2D = $TerminalArea
@onready var exit_area: Area2D = $ExitArea
@onready var terminal_ui: Control = $TerminalUI
@onready var chat: RichTextLabel = $TerminalUI/Chat
@onready var query_input: LineEdit = $TerminalUI/QueryInput
@onready var query_btn: Button = $TerminalUI/QueryBtn
@onready var back_btn: Button = $TerminalUI/BackBtn
@onready var phone: CanvasLayer = $Phone
@onready var submit_phone_btn: Button = $TerminalUI/FileList/SubmitPhoneBtn
@onready var log_view: Control = $TerminalUI/LogView
@onready var log_label: Label = $TerminalUI/LogView/Panel/Line
@onready var next_btn: Button = $TerminalUI/LogView/Panel/NextBtn
@onready var log_close: Button = $TerminalUI/LogView/Panel/CloseBtn

var log_idx := 0
var _http: HTTPRequest
var _querying := false

func _ready() -> void:
	Music.play_police_ambience()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 14.0
	_http.request_completed.connect(_on_query_reply)
	query_btn.pressed.connect(_on_query_submit)
	query_input.text_submitted.connect(func(_t: String) -> void: _on_query_submit())
	prompt.visible = false
	terminal_ui.visible = false
	back_btn.pressed.connect(_close_terminal)
	# 接入老人手机解锁日志
	log_view.visible = false
	submit_phone_btn.pressed.connect(_submit_phone)
	next_btn.pressed.connect(_log_next)
	log_close.pressed.connect(_close_log)
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = terminal_ui.visible)
	Game.place_player(self, player)
	# 没拿到老人手机就别显示"接入手机"(也防止已解锁后重复解锁)
	_refresh_terminal_actions()
	_update_prompt()
	_restore_chat()   # 离开终端室再回来：把全局存下的聊天记录重渲染回去

# 离开终端场景时兜底还原全局按钮位置(正常情况由 _close_terminal 还原)。
func _exit_tree() -> void:
	Inv.set_terminal_compact(false)
	Evidence.set_terminal_compact(false)

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(terminal_area):
		prompt.text = "空格  使用终端"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "↑ 返回  走廊"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

# 出口按 W/↑ 返回走廊；终端机按空格使用(打开查询界面)
func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if event.is_action_pressed("move_up") and _at(exit_area):
		_go(POLICE, "terminal")
	elif event.is_action_pressed("ui_select") and _at(terminal_area) and not terminal_ui.visible:
		_open_terminal()

func _open_terminal() -> void:
	Sfx.play_click()
	_refresh_terminal_actions()
	terminal_ui.visible = true
	player.locked = true
	prompt.visible = false
	# 仅在终端查询界面打开时，全局证据/道具左移，给「关闭终端」让出最右。
	Inv.set_terminal_compact(true)
	Evidence.set_terminal_compact(true)

func _close_terminal() -> void:
	Sfx.play_click()
	log_view.visible = false
	terminal_ui.visible = false
	player.locked = false
	# 防"幽灵按键"：在查询界面里打字时按了 ↑↓←→ 移光标，方向键也绑定 move_* 动作，
	# 释放事件被输入框吞掉→残留成"按住"。关终端不重载场景，clear_movement_input(只在
	# _ready 跑)不触发→解锁后玩家被残留键带着自动走。这里主动清掉残留。
	PlayerScript.clear_movement_input()
	_update_prompt()
	# 关掉查询界面 → 证据/道具按钮还原靠右。
	Inv.set_terminal_compact(false)
	Evidence.set_terminal_compact(false)

func _refresh_terminal_actions() -> void:
	# 有老人手机就一直显示该按钮；翻完日志(molog)后仍可重看历史，不再一关就消失。
	submit_phone_btn.visible = Game.state.has_item("oldman_phone")
	submit_phone_btn.text = "📱 重看莫忘历史日志" if Game.state.has_key("molog") else "📱 接入手机·恢复历史日志"

# 接入老人的手机 → 终端恢复全部历史日志 → 打开莫忘滑坡日志逐条翻(取证解锁)
func _submit_phone() -> void:
	if not Game.state.has_item("oldman_phone"):
		return
	Sfx.play_click()
	_append("终端", "接入成功。本地只剩今天的对话，正在从云端恢复……\n✅ 已恢复全部历史日志。")
	log_idx = 0
	log_label.text = str(Content.MOWANG_LOG_LINES[0])
	next_btn.text = "下一条 ▼"
	next_btn.disabled = false
	log_view.visible = true

func _log_next() -> void:
	Sfx.play_click()
	if log_idx < Content.MOWANG_LOG_LINES.size() - 1:
		log_idx += 1
		log_label.text = str(Content.MOWANG_LOG_LINES[log_idx])
		if log_idx >= Content.MOWANG_LOG_LINES.size() - 1:
			next_btn.text = "（已看完）"
			next_btn.disabled = true
			_finish_log()

func _finish_log() -> void:
	Game.state.add_key("molog")   # 第二层真相钥匙
	Evidence.note("molog")
	_refresh_terminal_actions()
	if Game.state.fire_hint("go_confront", str(Content.MOWANG_HINTS["go_confront"])):
		phone.notify_hint()

func _close_log() -> void:
	Sfx.play_click()
	log_view.visible = false

# —— 自然语言查询：聊天渲染 ——
# _append：存进全局(跨场景保留) + 渲染；_render_chat_line：只渲染(重进终端时回放用，不重复存)。
func _append(who: String, msg: String) -> void:
	Game.state.add_terminal_chat(who, msg)
	_render_chat_line(who, msg)

func _render_chat_line(who: String, msg: String) -> void:
	var color := "9ad6a0" if who == "终端" else "cfe6ff"
	chat.append_text("\n[color=#%s]%s：[/color]%s\n" % [color, who, msg])

# 重进终端室：把全局存下的聊天记录逐条渲染回聊天窗(不再走 _append，避免重复入库)。
func _restore_chat() -> void:
	for line in Game.state.terminal_chat:
		_render_chat_line(str(line.get("who", "")), str(line.get("msg", "")))

func _on_query_submit() -> void:
	if _querying:
		return
	var q := query_input.text.strip_edges()
	if q == "":
		return
	query_input.text = ""
	Sfx.play_click()
	_append("你", q)
	_querying = true
	query_btn.disabled = true
	chat.append_text("\n[color=#6f8f78]检索中…[/color]\n")
	_pending_query = q
	var err := _http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, LLM.terminal_request_body(q))
	if err != OK:
		_resolve_query(LLM.terminal_local_match(q))

var _pending_query := ""

func _on_query_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _querying:
		return
	var id := ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		id = LLM.parse_terminal_result(LLM.extract_content(data))
	else:
		# 模型失败/超时/401 → 本地关键词兜底，永不卡死
		id = LLM.terminal_local_match(_pending_query)
	_resolve_query(id)

func _resolve_query(id: String) -> void:
	_querying = false
	query_btn.disabled = false
	if id != "" and Content.TERMINAL_FILES.has(id):
		_append("终端", str(Content.TERMINAL_FILES[id]["text"]))
		_grant_and_hint(id)
	else:
		_append("终端", "无匹配记录。换个说法试试，或查某个人 / 某条记录。")

# 旧 _show 的副作用：查到带 grants_key 的档案 → 发钥匙 + 触发回审讯室提醒（去重）
func _grant_and_hint(id: String) -> void:
	var f = Content.TERMINAL_FILES.get(id)
	if f == null:
		return
	var k := str(f.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)
		Evidence.note(k)
	if FILE_HINTS.has(id):
		var hid: String = FILE_HINTS[id]
		if Content.MOWANG_HINTS.has(hid) and Game.state.fire_hint(hid, str(Content.MOWANG_HINTS[hid])):
			phone.notify_hint()

func _go(scene_path: String, entry: String) -> void:
	Game.spawn_point = entry
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
# ESC 现在专用于打开设置；返回走廊用屏幕上的「← 返回走廊」按钮。
