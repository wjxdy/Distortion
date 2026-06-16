# 审讯场景逻辑：Coffee Talk 式面对面对话。
# 静态界面（背景/立绘/裂痕/标题/输入栏/回看面板/Timer/Http）在 interrogation.tscn 里，可在编辑器调。
# 动态部分（带尖气泡、横幅、情绪精灵切换、真相演出）留在这里。
# 游戏逻辑(钥匙/钩子/真相)沿用 game/*。
extends Control

const GameState = preload("res://game/game_state.gd")
const Content = preload("res://game/content.gd")
const Triggers = preload("res://game/triggers.gd")
const Explore = preload("res://game/explore.gd")

const BACKEND_URL := "http://localhost:8787/chat"

const COL_PLAYER := Color(0.12, 0.30, 0.46, 0.92)   # 你的气泡：冷蓝
const COL_ZHOU := Color(0.17, 0.16, 0.14, 0.95)     # 他的气泡：暖灰
const BUBBLE_W := 470.0

# 周明远情绪精灵图：4 行情绪 × 4 列帧(慢速 idle，乒乓播放)，每格 256×192
const EMO_SHEET := "res://art/zhou_emotions.png"
const EMO_CW := 256
const EMO_CH := 192
const EMO_ROW := {"calm": 0, "angry": 1, "sinister": 2, "sad": 3}

# 带尖三角（气泡的"尖尖"，指向说话人）
class Tail extends Control:
	var dir := "down"
	var col := Color.WHITE
	func _draw() -> void:
		var w := 22.0
		var h := 14.0
		var pts: PackedVector2Array
		if dir == "down":
			pts = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.5, h)])
		else:
			pts = PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w * 0.5, 0)])
		draw_colored_polygon(pts, col)

var state
var emo_frames := []      # emo_frames[row][col] = AtlasTexture
var emo_row := 0
var emo_frame := 0
var emo_dir := 1
var player_wrap: Control
var zhou_wrap: Control
var zhou_label: Label
var last_user_msg := ""
var type_tween: Tween
var finished := false

@onready var portrait: TextureRect = $Portrait
@onready var crack: TextureRect = $Crack
@onready var status_label: Label = $Status
@onready var input: LineEdit = $Bar/Input
@onready var send_btn: Button = $Bar/SendBtn
@onready var explore_btn: Button = $Bar/ExploreBtn
@onready var backlog_btn: Button = $Bar/BacklogBtn
@onready var backlog_panel: Panel = $BacklogPanel
@onready var backlog_label: RichTextLabel = $BacklogPanel/Margin/VBox/BacklogLabel
@onready var close_btn: Button = $BacklogPanel/Margin/VBox/CloseBtn
@onready var emo_timer: Timer = $EmoTimer
@onready var http: HTTPRequest = $Http

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）：例如 Sfx.play_bgm("res://audio/interrogation_theme.ogg")
	state = GameState.new()

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
	explore_btn.pressed.connect(_on_explore)
	backlog_btn.pressed.connect(_toggle_backlog)
	close_btn.pressed.connect(_toggle_backlog)
	send_btn.pressed.connect(_send)
	input.text_submitted.connect(_on_submit)
	emo_timer.timeout.connect(_emo_tick)
	http.request_completed.connect(_on_reply)
	input.grab_focus()

	_log("[color=#888][案情] 老人周明远，行为异常，疑似 AI 被劫持。问出真相。[/color]")
	_log("[color=#888][提示] 直接打字盘问。撞墙了？点【查档案】拿线索，再回来追问。[/color]")
	# 审讯开场：周明远本人喃喃自语（记忆错乱当场可见）
	_show_zhou_bubble("今天……是几号了。\n她出门有一会儿了，怎么还不回来。")

func _log(line: String) -> void:
	backlog_label.append_text(line + "\n\n")

func _toggle_backlog() -> void:
	Sfx.play_click()
	backlog_panel.visible = not backlog_panel.visible

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

# ---------- 气泡 ----------

func _new_bubble(tail_dir: String, col: Color) -> Dictionary:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(14)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 13
	sb.content_margin_bottom = 13
	panel.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BUBBLE_W, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	label.add_theme_constant_override("line_spacing", 6)
	panel.add_child(label)

	var tail := Tail.new()
	tail.dir = tail_dir
	tail.col = col
	tail.size = Vector2(22, 14)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE

	wrap.add_child(panel)
	wrap.add_child(tail)
	add_child(wrap)
	return {"wrap": wrap, "panel": panel, "label": label, "tail": tail}

func _place_bubble(b: Dictionary, mode: String) -> void:
	var panel: PanelContainer = b["panel"]
	var tail: Tail = b["tail"]
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	var x := (1280.0 - sz.x) * 0.5
	if mode == "top":
		var y := 330.0
		panel.position = Vector2(x, y)
		tail.position = Vector2(x + sz.x * 0.5 - 11.0, y - 13.0)
	else:
		var y := 720.0 - 150.0 - sz.y
		panel.position = Vector2(x, y)
		tail.position = Vector2(x + sz.x * 0.5 - 11.0, y + sz.y - 1.0)

func _show_player_bubble(text: String) -> void:
	if is_instance_valid(player_wrap):
		player_wrap.queue_free()
	var b := _new_bubble("down", COL_PLAYER)
	player_wrap = b["wrap"]
	b["label"].text = text          # 玩家自己写的，整段直接显示
	_place_bubble.call_deferred(b, "bottom")

func _show_zhou_bubble(text: String) -> void:
	if is_instance_valid(zhou_wrap):
		zhou_wrap.queue_free()
	var b := _new_bubble("up", COL_ZHOU)
	zhou_wrap = b["wrap"]
	zhou_label = b["label"]
	zhou_label.text = text
	zhou_label.visible_ratio = 0.0
	_place_bubble.call_deferred(b, "top")
	_typewriter(zhou_label, text)

func _typewriter(label: Label, full: String) -> void:
	var dur: float = clampf(full.length() * 0.04, 0.4, 2.6)
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	type_tween = create_tween()
	type_tween.tween_property(label, "visible_ratio", 1.0, dur)

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
	if is_instance_valid(zhou_wrap):
		zhou_wrap.queue_free()        # 切到新一轮：清掉他上一句气泡
	_log("[color=#8fd0ff]你：[/color]" + msg)
	state.add_to_history("user", msg)
	input.text = ""
	_set_busy(true)
	var body := JSON.stringify({"history": state.history})
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

func _on_explore() -> void:
	var r := Explore.perform(state, "archive")
	if not r.is_empty():
		Sfx.play_click()
		_log("[color=#a0e8a0]📂 " + str(r["text"]) + "[/color]")
		_banner("📂 " + str(r["text"]), Color(0.63, 0.91, 0.63), 4.5)

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

func _input(event: InputEvent) -> void:
	# 【临时调试】F1-F4 切换表情，方便验收效果；接好 LLM emotion 后可删
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: _set_emotion("calm")
			KEY_F2: _set_emotion("angry")
			KEY_F3: _set_emotion("sinister")
			KEY_F4: _set_emotion("sad")
