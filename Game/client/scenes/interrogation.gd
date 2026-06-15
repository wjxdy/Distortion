# 审讯场景控制器：串起 UI、后端对话、钥匙/钩子/真相判定。
# UI 全部代码创建，.tscn 只是挂这个脚本的根节点。
extends Control

const GameState = preload("res://game/game_state.gd")
const Content = preload("res://game/content.gd")
const Triggers = preload("res://game/triggers.gd")
const Explore = preload("res://game/explore.gd")

const BACKEND_URL := "http://localhost:8787/chat"

var state
var http: HTTPRequest
var log_label: RichTextLabel
var input: LineEdit
var send_btn: Button
var explore_btn: Button
var last_user_msg := ""

func _ready() -> void:
	state = GameState.new()
	_build_ui()
	_append("[color=#888][案情] 老人周明远，行为异常，疑似 AI 被劫持。问出真相。[/color]")
	_append("[color=#888][提示] 直接打字盘问。撞墙了？点【查档案】拿线索，再回来追问。[/color]")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "审讯室 · 周明远"
	vbox.add_child(title)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(log_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	input = LineEdit.new()
	input.placeholder_text = "盘问他……（回车发送）"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(_on_submit)
	row.add_child(input)

	send_btn = Button.new()
	send_btn.text = "盘问"
	send_btn.pressed.connect(_send)
	row.add_child(send_btn)

	explore_btn = Button.new()
	explore_btn.text = "查档案"
	explore_btn.pressed.connect(_on_explore)
	row.add_child(explore_btn)

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_reply)

	input.grab_focus()

func _append(line: String) -> void:
	log_label.append_text(line + "\n\n")

func _on_submit(_t: String) -> void:
	_send()

func _send() -> void:
	var msg := input.text.strip_edges()
	if msg == "":
		return
	last_user_msg = msg
	_append("[color=#8fd0ff]你：[/color]" + msg)
	state.add_to_history("user", msg)
	input.text = ""
	_set_busy(true)
	var body := JSON.stringify({"history": state.history})
	var err := http.request(BACKEND_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_append("[color=#ff6b6b]（无法连接后端，确认 server 已启动：cd Game/server && npm start）[/color]")
		_set_busy(false)

func _on_reply(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_busy(false)
	var data = JSON.parse_string(body.get_string_from_utf8())
	if code != 200 or typeof(data) != TYPE_DICTIONARY or not data.has("reply"):
		var emsg := ""
		if typeof(data) == TYPE_DICTIONARY and data.has("error"):
			emsg = str(data["error"])
		_append("[color=#ff6b6b]（出错 %d）%s[/color]" % [code, emsg])
		return
	_append("[color=#e8e1c8]周明远：[/color]" + str(data["reply"]))
	state.add_to_history("assistant", str(data["reply"]))
	_check_truths()

func _check_truths() -> void:
	for id in Triggers.evaluate(state, last_user_msg):
		state.reveal(id)
		_append("[color=#ffd166]💥 " + Triggers.fragment_of(id) + "[/color]")
	if state.revealed.size() >= Content.TRUTHS.size():
		_append("[color=#c792ea]=== " + Content.ENDING + " ===[/color]")
		input.editable = false
		send_btn.disabled = true

func _on_explore() -> void:
	var r := Explore.perform(state, "archive")
	if not r.is_empty():
		_append("[color=#a0e8a0]📂 " + str(r["text"]) + "[/color]")

func _set_busy(b: bool) -> void:
	send_btn.disabled = b
	input.editable = not b
	if not b:
		input.grab_focus()
