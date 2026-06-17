# 审讯场景逻辑：Coffee Talk 式面对面对话。
# 静态界面（背景/立绘/裂痕/标题/输入栏/回看面板/两个气泡/Timer/Http）在 interrogation.tscn 里，
# 可在编辑器里拖位置、拉大小。脚本只负责逻辑 + 往气泡填字 + 打字机 + 情绪/真相演出。
# 游戏逻辑(钥匙/钩子/真相)沿用 game/*。
extends Control

const GameState = preload("res://game/game_state.gd")
const Content = preload("res://game/content.gd")
const Triggers = preload("res://game/triggers.gd")
const Explore = preload("res://game/explore.gd")

const BACKEND_URL := "http://localhost:8787/chat"
const POLICE := "res://scenes/police.tscn"

# 周明远情绪精灵图：4 行情绪 × 4 列帧(慢速 idle，乒乓播放)，每格 256×192
const EMO_SHEET := "res://art/zhou_emotions.png"
const EMO_CW := 256
const EMO_CH := 192
const EMO_ROW := {"calm": 0, "angry": 1, "sinister": 2, "sad": 3}

var state
var emo_frames := []      # emo_frames[row][col] = AtlasTexture
var emo_row := 0
var emo_frame := 0
var emo_dir := 1
var last_user_msg := ""
var type_tween: Tween
var finished := false

@onready var portrait: TextureRect = $Portrait
@onready var crack: TextureRect = $Crack
@onready var status_label: Label = $Status
@onready var input: LineEdit = $Bar/Input
@onready var send_btn: Button = $Bar/SendBtn
@onready var phone: CanvasLayer = $Phone   # 可复用手机 UI(查档案在这里)
@onready var zhou_bubble: Panel = $ZhouBubble
@onready var zhou_label: Label = $ZhouBubble/Margin/VBox/Content
@onready var player_bubble: Panel = $PlayerBubble
@onready var player_label: Label = $PlayerBubble/Margin/Content
@onready var emo_timer: Timer = $EmoTimer
@onready var http: HTTPRequest = $Http
@onready var back_btn: Button = $BackBtn

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）：例如 Sfx.play_bgm("res://audio/interrogation_theme.ogg")
	state = Game.state   # 用全局状态：手机/终端拿的线索跨场景保留

	# 情绪精灵图切片：emo_frames[row][col]
	var sheet := load(EMO_SHEET)
	for r in 4:
		var row := []
		for c in 4:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(c * EMO_CW, r * EMO_CH, EMO_CW, EMO_CH)
			row.append(at)
		emo_frames.append(row)
	_apply_emo_frame()

	# 连信号
	send_btn.pressed.connect(_send)
	input.text_submitted.connect(_on_submit)
	emo_timer.timeout.connect(_emo_tick)
	http.request_completed.connect(_on_reply)
	back_btn.pressed.connect(_back)   # 返回走廊按钮在 .tscn 里，可在编辑器拖位置
	# 看手机时禁用盘问输入栏（查档案在手机里）
	phone.opened.connect(func() -> void: _bar_enabled(false))
	phone.closed.connect(func() -> void: _bar_enabled(not finished))
	input.grab_focus()

	# 开场：首次进来 → 周明远喃喃自语(记忆错乱)；带着历史回访 → 接上他上一句，不重置
	var last_zhou := ""
	for i in range(state.history.size() - 1, -1, -1):
		if str(state.history[i].get("role")) == "assistant":
			last_zhou = str(state.history[i].get("content"))
			break
	if last_zhou == "":
		_show_zhou_bubble("今天……是几号了。\n她出门有一会儿了，怎么还不回来。")
	else:
		_show_zhou_bubble(last_zhou)

func _log(_line: String) -> void:
	pass   # 回看记录功能已移除；保留调用点为空操作，不影响其它逻辑

func _bar_enabled(b: bool) -> void:
	input.editable = b
	send_btn.disabled = not b
	if b:
		input.grab_focus()

# ---------- 情绪立绘 ----------

func _apply_emo_frame() -> void:
	portrait.texture = emo_frames[emo_row][emo_frame]

func _emo_tick() -> void:
	# 乒乓：0→1→2→3→2→1→0…（睁眼→闭眼来回，自然 idle）
	emo_frame += emo_dir
	if emo_frame >= 3:
		emo_frame = 3
		emo_dir = -1
	elif emo_frame <= 0:
		emo_frame = 0
		emo_dir = 1
	_apply_emo_frame()

func _set_emotion(emo: String) -> void:
	if not EMO_ROW.has(emo):
		emo = "calm"
	emo_row = EMO_ROW[emo]
	emo_frame = 0
	emo_dir = 1
	_apply_emo_frame()

# ---------- 气泡（位置/大小在 .tscn 里调，这里只填字 + 显隐 + 打字机） ----------

func _show_player_bubble(text: String) -> void:
	player_bubble.visible = true
	player_label.text = text          # 玩家自己写的，整段直接显示
	player_label.visible_ratio = 1.0

func _show_zhou_bubble(text: String) -> void:
	zhou_bubble.visible = true
	zhou_label.text = text
	zhou_label.visible_ratio = 0.0
	_typewriter(zhou_label, text)

func _typewriter(label: Label, full: String) -> void:
	var dur: float = clampf(full.length() * 0.04, 0.4, 2.6)
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	Sfx.start_typing()   # 老头打字时循环播打字机音效
	type_tween = create_tween()
	type_tween.tween_property(label, "visible_ratio", 1.0, dur)
	type_tween.tween_callback(Sfx.stop_typing)   # 打完即停

# ---------- 对话流程 ----------

func _on_submit(_t: String) -> void:
	_send()

func _send() -> void:
	if finished:
		return
	var msg := input.text.strip_edges()
	if msg == "":
		return
	last_user_msg = msg
	Sfx.play_click()
	_show_player_bubble(msg)
	zhou_bubble.visible = false        # 切到新一轮：清掉他上一句气泡
	_log("[color=#8fd0ff]你：[/color]" + msg)
	state.add_to_history("user", msg)
	input.text = ""
	_set_busy(true)
	# 把"调查进展"系统旁白拼在历史最前发给模型(让老头知道你查到了什么)；不写进持久化历史
	var to_send: Array = []
	var prog = state.investigation_summary()
	if prog != "":
		to_send.append({"role": "system", "content": prog})
	to_send.append_array(state.history)
	var body := JSON.stringify({"history": to_send})
	var err := http.request(BACKEND_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if err != OK:
		_banner("连不上后端，请先启动：cd Game/server && npm start", Color(1, 0.45, 0.45))
		_set_busy(false)

func _on_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_busy(false)
	if result != HTTPRequest.RESULT_SUCCESS or body.size() == 0:
		_banner("连不上后端，请先启动：cd Game/server && npm start", Color(1, 0.45, 0.45))
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if code != 200 or typeof(data) != TYPE_DICTIONARY or not data.has("reply"):
		var emsg := ""
		if typeof(data) == TYPE_DICTIONARY and data.has("error"):
			emsg = str(data["error"])
		_banner("出错 %d %s" % [code, emsg], Color(1, 0.45, 0.45))
		return
	# 表情：后端若返回 emotion 则按它切，缺省 calm（接 LLM emotion 即生效）
	if typeof(data) == TYPE_DICTIONARY and data.has("emotion"):
		_set_emotion(str(data["emotion"]))
	var reply := str(data["reply"])
	_show_zhou_bubble(reply)
	_log("[color=#e8e1c8]周明远：[/color]" + reply)
	state.add_to_history("assistant", reply)
	_check_truths()
	_handle_hint(data)

# 莫忘提醒：模型在 hint 字段给出节点ID → 去重(整局只一次)后弹提示条 + 手机红点。
func _handle_hint(data) -> void:
	if typeof(data) != TYPE_DICTIONARY or not data.has("hint"):
		return
	var id := str(data["hint"])
	if id == "" or not Content.MOWANG_HINTS.has(id):
		return
	var text := str(Content.MOWANG_HINTS[id])
	if state.fire_hint(id, text):   # 只有首次触发才提示
		phone.notify_hint()         # 响声 + 红点 + 右上角小字(详情在手机莫忘 app)

func _check_truths() -> void:
	for id in Triggers.evaluate(state, last_user_msg):
		state.reveal(id)
		var frag := Triggers.fragment_of(id)
		_log("[color=#ffd166]💥 " + frag + "[/color]")
		_set_emotion("sad")   # 真相浮现 = 妻子之死，他陷入悲伤
		_play_crack()
		_banner("💥 " + frag, Color(1, 0.82, 0.4), 4.0)
	if state.revealed.size() >= Content.TRUTHS.size():
		finished = true
		_banner(Content.ENDING, Color(0.78, 0.57, 0.92), 6.0)
		_log("[color=#c792ea]=== " + Content.ENDING + " ===[/color]")
		input.editable = false
		send_btn.disabled = true

func _set_busy(b: bool) -> void:
	send_btn.disabled = b or finished
	input.editable = (not b) and (not finished)
	status_label.text = "周明远正在回忆……" if b else ""
	if not b and not finished:
		input.grab_focus()

# ---------- 通用横幅（探索 / 真相 / 结尾 / 报错） ----------

func _banner(text: String, col: Color, hold: float = 3.0) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.z_index = 60
	add_child(cc)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.82)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = col
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)

	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", col)
	panel.add_child(l)

	cc.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(cc, "modulate:a", 1.0, 0.4)
	tw.tween_interval(hold)
	tw.tween_property(cc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cc.queue_free)

func _play_crack() -> void:
	Sfx.play_reveal()
	crack.visible = true
	crack.modulate = Color(1, 1, 1, 0.0)
	crack.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(crack, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(crack, "scale", Vector2(1.1, 1.1), 0.45)
	tw.tween_interval(0.7)
	tw.tween_property(crack, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: crack.visible = false)

func _back() -> void:
	Sfx.play_door()
	get_tree().change_scene_to_file(POLICE)

func _input(event: InputEvent) -> void:
	# Esc 返回警局走廊
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	# 【临时调试】F1-F4 切换表情，方便验收效果；接好 LLM emotion 后可删
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: _set_emotion("calm")
			KEY_F2: _set_emotion("angry")
			KEY_F3: _set_emotion("sinister")
			KEY_F4: _set_emotion("sad")
