# 审讯场景逻辑：Coffee Talk 式面对面对话。
# 静态界面（背景/立绘/裂痕/标题/输入栏/回看面板/两个气泡/Timer/Http）在 interrogation.tscn 里，
# 可在编辑器里拖位置、拉大小。脚本只负责逻辑 + 往气泡填字 + 打字机 + 情绪/真相演出。
# 游戏逻辑(钥匙/钩子/真相)沿用 game/*。
extends Control

const GameState = preload("res://game/game_state.gd")
const Content = preload("res://game/content.gd")
const Triggers = preload("res://game/triggers.gd")
const Explore = preload("res://game/explore.gd")
const LLM = preload("res://game/llm.gd")   # 客户端直连大模型(提示词+调用+解析,替代后端)

# 直连大模型：地址/密钥/提示词/解析都在 LLM(game/llm.gd)，不再走自建后端。
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

# 失败重试：任何失败都重试，共 MAX_TRIES 次、递增延迟，用尽才出保底沉默「……」。
const MAX_TRIES := 3
const RETRY_DELAYS := [0.6, 1.2]   # 第1次失败后等0.6s重试，第2次失败后等1.2s重试
var _req_body := ""
var _attempt := 0
var _req_start := 0

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
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var end_slide: Control = $EndSlide
@onready var end_body: Label = $EndSlide/VBox/Body
@onready var end_subtitle: Label = $EndSlide/VBox/Subtitle

func _ready() -> void:
	Music.play_police_ambience()
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
	http.timeout = 25.0   # 超时→保底沉默(原后端 14s,直连放宽到 25s 容 Moonshot 偶发慢)
	back_btn.pressed.connect(_back)   # 返回走廊按钮在 .tscn 里，可在编辑器拖位置
	end_slide.visible = false
	fade_overlay.visible = false
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

func _show_zhou_bubble(text: String, play_sound: bool = true) -> void:
	zhou_bubble.visible = true
	zhou_label.text = text
	zhou_label.visible_ratio = 0.0
	_typewriter(zhou_label, text, play_sound)

# play_sound=false 时不播打字机音效——给保底沉默「……」用(他没在打字，别发那声"嘣")。
func _typewriter(label: Label, full: String, play_sound: bool = true) -> void:
	var dur: float = clampf(full.length() * 0.04, 0.4, 2.6)
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	if play_sound:
		Sfx.start_typing()   # 老头打字时循环播打字机音效
	type_tween = create_tween()
	type_tween.tween_property(label, "visible_ratio", 1.0, dur)
	if play_sound:
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
	# 直连大模型：非终局把"已出示证据"系统旁白拼在历史最前(让老头知道玩家拿出了什么,不写进持久化历史)；
	# 终局由 LLM.build_messages 自动换成 FINALE 提示，这里不注入旁白。
	var to_send: Array = []
	if not state.in_finale():
		var prog = state.presented_proofs()
		if prog != "":
			to_send.append({"role": "system", "content": prog})
	to_send.append_array(state.history)
	_req_body = LLM.request_body(to_send, state.in_finale())
	_attempt = 0
	_do_request()

# 发一次请求（带尝试计数/计时）。失败/重试逻辑统一在 _on_reply 里。
func _do_request() -> void:
	_attempt += 1
	_req_start = Time.get_ticks_msec()
	var err := http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, _req_body)
	if err != OK:
		# 连请求都发不出去：当作一次失败，交给统一的失败/重试处理
		_on_reply(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())

func _on_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var elapsed := (Time.get_ticks_msec() - _req_start) / 1000.0
	# 直连大模型：成功则取 choices[0].message.content 解析。
	var parsed: Dictionary = {}
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0:
		var data = JSON.parse_string(body.get_string_from_utf8())
		var content := LLM.extract_content(data)
		if content != "":
			parsed = LLM.parse_reply(content)
	# 成功：拿到非空回复
	if not parsed.is_empty() and not str(parsed.get("reply", "")).is_empty():
		Dbg.log_req(_attempt, true, code, "正常回复", elapsed)
		_set_busy(false)
		_apply_reply(parsed)
		return
	# 失败：先翻译原因，能重试就按递增延迟重试，用尽才保底沉默
	var reason := LLM.fail_reason(result, code, body.get_string_from_utf8() if body.size() > 0 else "")
	if code == 401 or code == 403:
		reason += "  [" + LLM.key_fingerprint() + "]"   # 鉴权失败时标出用的哪个 key
	if _attempt < MAX_TRIES and not finished:
		var d: float = RETRY_DELAYS[mini(_attempt - 1, RETRY_DELAYS.size() - 1)]
		Dbg.log_req(_attempt, false, code, "%s → %.1fs后重试" % [reason, d], elapsed)
		await get_tree().create_timer(d).timeout
		if finished:
			return
		_do_request()
		return
	# 重试用尽 → 保底沉默(演成周明远装糊涂/阿尔茨海默)
	Dbg.log_req(_attempt, false, code, reason + " → 重试用尽，保底沉默……", elapsed)
	_set_busy(false)
	_apply_reply(LLM.pick_silence(), true)   # silent=true：沉默「……」不播打字机音效(去掉那声"嘣")

# 把一条(成功或沉默的)回复落地：切表情、弹气泡、进历史、判定真相/提醒/终局。
# silent=true 用于保底沉默「……」：不播打字机音效。
func _apply_reply(parsed: Dictionary, silent: bool = false) -> void:
	_set_emotion(str(parsed.get("emotion", "calm")))
	var reply := str(parsed.get("reply", "……"))
	_show_zhou_bubble(reply, not silent)
	_log("[color=#e8e1c8]周明远：[/color]" + reply)
	state.add_to_history("assistant", reply)
	_check_truths()
	_handle_hint(parsed)        # 模型吐的 hint 标签
	_hint_fallback(reply)       # 兜底：按对话内容+进度确定性补发
	_handle_end(parsed)         # 终局：[[end:reveal/comfort]] → 触发结局

# 统一发提醒：去重(整局只一次)后弹右上角小字 + 手机响声红点。
func _fire_hint(id: String) -> void:
	if id == "" or not Content.MOWANG_HINTS.has(id):
		return
	if state.fire_hint(id, str(Content.MOWANG_HINTS[id])):
		phone.notify_hint()

# 模型在 hint 字段给出节点ID 时触发。
func _handle_hint(data) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("hint"):
		_fire_hint(str(data["hint"]))

# 玩家这一句是否在「当面质疑 AI 说法 / 亮证据对质」(用于 visit_community 闸门)：
# 要么质问 AI 的确定性，要么主张她是自然病逝/查无事故。措辞放宽，尽量覆盖自由输入。
func _challenges_ai(m: String) -> bool:
	var mentions_ai: bool = ("AI" in m) or ("Ａｉ" in m) or ("人工智能" in m)
	var doubts: bool = ("为什么" in m) or ("凭什么" in m) or ("确定" in m) or ("怎么知道" in m) or ("怎么确定" in m) or ("真的" in m)
	if mentions_ai and doubts:
		return true
	return ("病死" in m) or ("病逝" in m) or ("自然" in m) or ("不是AI" in m) or ("不是 AI" in m) \
		or ("诊断" in m) or ("没有事故" in m) or ("查无" in m) or ("没事故" in m) or ("证据" in m)

# 兜底：模型没吐标签(过载/漏吐/被去重)时，按老头这轮回复 + 玩家问话 + 调查进度确定性补发。
# fire_hint 自带去重，所以和模型不会重复触发。
func _hint_fallback(reply: String) -> void:
	var blames_ai: bool = ("AI" in reply) or ("Ａｉ" in reply) or ("误诊" in reply)
	var has_evidence: bool = state.has_key("linxiulan") or state.has_key("farewell")
	if blames_ai:
		# 去小区要等你「当面质问 AI 说法」而他仍咬定时才弹——否则你刚查完回来他随口提 AI 就提早触发。
		if has_evidence and _challenges_ai(last_user_msg):
			_fire_hint("visit_community")     # 查过死因 + 当面质问仍咬定 → 去小区
		elif not has_evidence:
			_fire_hint("investigate_death")   # 还没查 → 去终端查死因
	var m := last_user_msg
	if ("莫忘" in m) or ("手机" in m) or ("app" in m) or ("APP" in m) or ("为什么用" in m) or ("天天" in m):
		_fire_hint("protecting_app")

# 终局：模型按玩家态度吐 [[end:reveal/comfort]] → 触发对应结局。
# (ready 已弃用;若模型偶吐别的值,这里不处理即忽略。leave 分支已移除。)
func _handle_end(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var e := str(data.get("end", ""))
	if e == "reveal" or e == "comfort":
		_trigger_ending(e)

# 渐黑 → 幻灯片(分支正文 + 统一字幕)。结局唯一入口；结束在此锁死。
func _trigger_ending(branch: String) -> void:
	if finished:
		return
	finished = true
	input.editable = false
	send_btn.disabled = true
	# 渐黑
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 1.4)
	tw.tween_callback(func() -> void: _show_end_slide(branch))

func _show_end_slide(branch: String) -> void:
	end_body.text = str(Content.ENDING_SLIDES.get(branch, ""))
	end_subtitle.text = str(Content.ENDING)
	end_slide.visible = true
	end_slide.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(end_slide, "modulate:a", 1.0, 1.2)

func _check_truths() -> void:
	# 静默记录真相(供结局/存档判定)。结束不再绑定"集齐真相"——只由终局对峙的玩家选择触发。
	for id in Triggers.evaluate(state, last_user_msg):
		state.reveal(id)

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
	# 真相裂痕只保留画面演出，去掉那声难听的"嘣"(reveal 音效)。
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
	Game.spawn_point = "interrogation"   # 回警局时落到审讯室门口
	Sfx.play_door()
	get_tree().change_scene_to_file(POLICE)

# 离开审讯室(返回按钮/Esc/切场景任意路径)时统一停打字机循环音效。
# 打字机用 Sfx(autoload 常驻)的循环 player,正常靠 tween 结束回调 stop;
# 但老头还在打字时中途退出,tween 连同本场景被销毁→回调漏触发→音效残留到警局走廊。
# _exit_tree 在节点离树时必触发,兜住所有离场路径。
func _exit_tree() -> void:
	Sfx.stop_typing()

func _input(event: InputEvent) -> void:
	# ESC 现在专用于打开设置(Settings autoload)；返回走廊用屏幕上的「返回」按钮。
	# 【临时调试】F1-F4 切换表情，方便验收效果；接好 LLM emotion 后可删
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: _set_emotion("calm")
			KEY_F2: _set_emotion("angry")
			KEY_F3: _set_emotion("sinister")
			KEY_F4: _set_emotion("sad")
