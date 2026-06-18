# 无头测试 runner：godot --headless --path <client> -s res://tests/run_tests.gd
# 退出码 0 = 全过，1 = 有失败。
extends SceneTree

const GameState = preload("res://game/game_state.gd")
const Content = preload("res://game/content.gd")
const Triggers = preload("res://game/triggers.gd")
const Explore = preload("res://game/explore.gd")
const LLM = preload("res://game/llm.gd")
const Dbg = preload("res://scenes/debug.gd")

var _pass := 0
var _fail := 0

func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("  ok  ", name)
	else:
		_fail += 1
		printerr("  FAIL ", name)

func _initialize() -> void:
	# --- GameState ---
	var s = GameState.new()
	_check(not s.has_key("linxiulan"), "初始无钥匙")
	s.add_key("linxiulan")
	_check(s.has_key("linxiulan"), "加钥匙后有")
	_check(not s.is_revealed("fact"), "初始未揭示")
	s.reveal("fact")
	_check(s.is_revealed("fact"), "揭示后为真")
	s.add_to_history("user", "你好")
	_check(s.history.size() == 1 and s.history[0]["role"] == "user", "历史可追加")

	# --- Triggers（去邪教版：两层真相，确定性 钥匙 + 关键词） ---
	var s2 = GameState.new()
	_check(Triggers.evaluate(s2, "是 AI 害死她的吗").is_empty(), "没钥匙不触发第一层")
	s2.add_key("linxiulan")
	_check(Triggers.evaluate(s2, "今天天气如何").is_empty(), "有钥匙无关键词不触发")
	_check(Triggers.evaluate(s2, "是 AI 害死她的吗") == ["fact"], "持档案+追问AI/害死 触发第一层真相(事实=病逝)")
	s2.reveal("fact")
	_check(Triggers.evaluate(s2, "是 AI 害死的").is_empty(), "第一层已揭示不再触发")
	# 第二层真相：需莫忘日志钥匙
	_check(Triggers.evaluate(s2, "是莫忘在骗你").is_empty(), "没莫忘日志钥匙不触发第二层")
	s2.add_key("molog")
	_check(Triggers.evaluate(s2, "是莫忘在骗你") == ["complicity"], "持莫忘日志+追问莫忘 触发第二层真相(同谋)")

	# --- Explore（去邪教版终端线索 -> 钥匙） ---
	var s3 = GameState.new()
	_check(Explore.perform(s3, "archive").get("key") == "linxiulan", "查档案授予 linxiulan")
	_check(Explore.perform(s3, "medical").get("key") == "no_accident", "查医疗记录授予 no_accident")
	_check(Explore.perform(s3, "molog").get("key") == "molog", "翻莫忘日志授予 molog")
	_check(Explore.perform(s3, "不存在").is_empty(), "未知探索返回空")

	# --- Content（去邪教版设定校验） ---
	_check(Content.TRUTHS.size() == 2, "两层真相")
	var frag_fact := Triggers.fragment_of("fact")
	_check(("查无" in frag_fact) or ("不是" in frag_fact) or ("病逝" in frag_fact), "第一层真相=查无事故/病逝/不是AI")
	var molog_text := ""
	for a in Content.EXPLORE_ACTIONS:
		if a["id"] == "molog":
			molog_text = a["text"]
	_check("莫忘" in molog_text, "莫忘日志文案存在")
	# 旧设定（周明远自制 AI / AI 之父）不应再出现在任何探索文案(含标签)里
	for a in Content.EXPLORE_ACTIONS:
		var blob := str(a.get("label", "")) + str(a.get("text", ""))
		_check(not ("自制" in blob), "无'自制AI'旧设定: " + str(a["id"]))

	# --- 终端案卷（警局电脑终端查询项） ---
	_check(Content.TERMINAL_FILES.has("wife") and Content.TERMINAL_FILES["wife"]["grants_key"] == "linxiulan", "终端·林秀兰记录授予 linxiulan")
	_check(Content.TERMINAL_FILES.has("medical") and Content.TERMINAL_FILES["medical"]["grants_key"] == "no_accident", "终端·医疗事故授予 no_accident")
	_check(("自然死亡" in Content.TERMINAL_FILES["wife"]["text"]), "终端·林秀兰记录=自然死亡")
	for fid in Content.TERMINAL_FILES:
		_check(Content.TERMINAL_FILES[fid]["text"] != "", "终端案卷有内容: " + str(fid))

	# --- 全局状态单例（跨场景保留线索：手机在 world 拿的钥匙，审讯室要还在） ---
	var GG = load("res://game/game_global.gd")
	_check(GG != null, "game_global.gd 存在(全局状态单例)")
	if GG:
		var g = GG.new()
		g.reset()
		g.state.add_key("linxiulan")
		_check(g.state.has_key("linxiulan"), "全局状态持有钥匙")
		g.reset()
		_check(not g.state.has_key("linxiulan"), "reset 后清空(新游戏)")
		g.free()

	# --- 莫忘提醒去重（同一提醒整局只触发一次） ---
	var s4 = GameState.new()
	_check(s4.has_method("fire_hint"), "GameState 有 fire_hint")
	if s4.has_method("fire_hint"):
		_check(s4.fire_hint("investigate_death", "去查死因") == true, "首次触发提醒=true")
		_check(s4.mowang_log.size() == 1 and s4.mowang_unread, "触发后记一条+标未读")
		_check(s4.fire_hint("investigate_death", "去查死因") == false, "同一提醒重复触发=false(去重)")
		_check(s4.mowang_log.size() == 1, "重复触发不再追加")
		_check(s4.fire_hint("", "x") == false, "空ID不触发")
		s4.read_mowang()
		_check(not s4.mowang_unread, "读过莫忘后转已读")

	# --- 调查进展摘要（喂给模型，让老头知道玩家查到了什么） ---
	var s5 = GameState.new()
	_check(s5.has_method("investigation_summary"), "GameState 有 investigation_summary")
	if s5.has_method("investigation_summary"):
		_check(s5.investigation_summary() == "", "无线索时进展摘要为空")
		s5.add_key("linxiulan")
		s5.add_key("no_accident")
		var summ = s5.investigation_summary()
		_check(("林秀兰" in summ) or ("自然" in summ), "摘要含林秀兰死因")
		_check(("查无" in summ) or ("事故" in summ), "摘要含医疗事故查无")

	# --- 开局任务红点（上司任务默认未读，看过转已读） ---
	var s6 = GameState.new()
	_check(s6.has_method("read_task"), "GameState 有 read_task")
	if s6.has_method("read_task"):
		_check(s6.task_unread, "开局上司任务默认未读(亮红点)")
		s6.read_task()
		_check(not s6.task_unread, "看过任务后转已读")

	# --- 道具栏（钥匙等实物，门禁判定用） ---
	var s7 = GameState.new()
	_check(s7.has_method("add_item"), "GameState 有 add_item")
	if s7.has_method("add_item"):
		_check(not s7.has_item("home_key"), "初始无钥匙道具")
		s7.add_item("home_key")
		_check(s7.has_item("home_key"), "拿到钥匙后 has_item 为真")
	_check(Content.ITEMS.has("home_key"), "道具表含 home_key")

	# --- 终局判定：拿到 molog 即进入终局(客户端据此发 finale 标志切后端提示) ---
	var s8 = GameState.new()
	_check(s8.has_method("in_finale") and not s8.in_finale(), "未拿日志不在终局")
	s8.add_key("molog")
	_check(s8.in_finale(), "拿到 molog → 进入终局")

	# --- 终局：日志蒙太奇 + 新提醒 + 三分支结局文案 ---
	_check(Content.MOWANG_HINTS.has("unlock_log"), "新增提醒 unlock_log(拿到手机→去终端解锁)")
	_check(Content.MOWANG_HINTS.has("go_confront"), "新增提醒 go_confront(解锁日志→回审讯对峙)")
	_check(not Content.MOWANG_HINTS.has("confront_molog"), "废弃提醒 confront_molog 已移除")
	_check(Content.ENDING_SLIDES.size() >= 3, "ENDING_SLIDES 三分支文案存在")
	for b in ["reveal", "comfort", "leave"]:
		_check(Content.ENDING_SLIDES.has(b) and str(Content.ENDING_SLIDES[b]) != "", "结局幻灯片有 " + b)
	# 日志蒙太奇：那条无理由跳变的"是 AI 害死的" + 点破空白的旁白
	var molog_blob := "\n".join(Content.MOWANG_LOG_LINES)
	_check("是 AI 害死的" in molog_blob, "日志含突兀跳变的'是 AI 害死的'")
	_check(("没有前一天" in molog_blob) or ("没有任何理由" in molog_blob), "日志含点破空白的旁白")

	# --- LLM.parse_reply（客户端直连版，移植自后端 llm.js parseReply） ---
	var r1 = LLM.parse_reply("[sad] 她……只是出门买点菜。 ")
	_check(r1["reply"] == "她……只是出门买点菜。" and r1["emotion"] == "sad" and r1["hint"] == "" and r1["end"] == "", "解析句首情绪+去空白")
	var r2 = LLM.parse_reply("[angry]是 AI 害死她的！[[hint:investigate_death]]")
	_check(r2["reply"] == "是 AI 害死她的！" and r2["emotion"] == "angry" and r2["hint"] == "investigate_death", "剥 [[hint:ID]]")
	var r3 = LLM.parse_reply("[sad]她就那么走了。[[end:reveal]]")
	_check(r3["reply"] == "她就那么走了。" and r3["end"] == "reveal", "剥 [[end:reveal]]")
	_check(LLM.parse_reply("[[end:boom]]你好")["end"] == "", "非法 end 不当标签")
	var r5 = LLM.parse_reply("[angry]是 AI 害的！[[hint:visit_community]][[end:ready]]")
	_check(r5["reply"] == "是 AI 害的！" and r5["hint"] == "visit_community" and r5["end"] == "ready", "hint+end 共存且都剥")
	var r6 = LLM.parse_reply("[angry]你们懂什么！\n\n[calm]好吧，我承认。")
	_check(r6["reply"] == "你们懂什么！\n\n好吧，我承认。" and r6["emotion"] == "angry", "中段情绪标签也剥,取第一个")
	_check(LLM.parse_reply("[happy]你好")["reply"] == "[happy]你好", "非法情绪标签原样保留")
	var r8 = LLM.parse_reply("我就……记记日常。   [[hint:protecting_app]]")
	_check(r8["reply"] == "我就……记记日常。" and r8["hint"] == "protecting_app", "尾部 hint 剥净不残留")
	# build_messages：终局换 FINALE，系统提示在最前
	var msgs = LLM.build_messages([{"role": "user", "content": "hi"}], false)
	_check(msgs.size() == 2 and msgs[0]["role"] == "system" and "周明远" in msgs[0]["content"], "build_messages 非终局用人设提示")
	var msgs_f = LLM.build_messages([], true)
	_check("终局" in msgs_f[0]["content"], "build_messages 终局换 FINALE")

	# --- 防"幽灵按键"：返回场景后玩家不被残留的移动键带着自动走 ---
	# 复现 bug：审讯室打字时某移动键(方向键/WASD)的释放在同步切场景时丢失，
	# 残留成"按住"留在全局 Input；新场景 Player 一进来就 get_vector 读到→自动走。
	# 修复=Player 进场景调 clear_movement_input() 清掉残留(_ready 里调用，见 player.gd)。
	var PlayerScript = load("res://scenes/player.gd")
	Input.action_press("move_right")
	_check(Input.is_action_pressed("move_right"), "幽灵按键已注入(复现前置)")
	PlayerScript.clear_movement_input()
	_check(not Input.is_action_pressed("move_right"), "Player.clear_movement_input 清除残留移动键(防返回后自动走)")

	# --- 打字机音效：离开审讯室必须停(防退出后老头打字机音效残留到警局) ---
	# 复现失败模式:打字机是 Sfx(autoload常驻)上的循环 player,正常靠 tween 结束回调 stop。
	# 老头还在打字时中途退出→tween 连同场景被销毁、回调漏触发→不主动停就会残留(still playing)。
	# 修复=审讯室 _exit_tree 调 Sfx.stop_typing()(见 interrogation.gd)。这里验证 stop 能停下循环。
	var sfx_t = load("res://autoload/sfx.gd").new()
	get_root().add_child(sfx_t)
	await process_frame                # 等 _ready 跑完建好 _typing_player
	sfx_t.start_typing()
	_check(sfx_t._typing_player.playing, "打字机开始→在播")
	# 模拟中途离场没触发 tween 回调:循环仍在播(=bug 残留态)
	_check(sfx_t._typing_player.playing, "未主动停→循环残留(复现:这正是退出后还响的原因)")
	sfx_t.stop_typing()                # 修复动作:离场统一停
	_check(not sfx_t._typing_player.playing, "stop_typing→循环停下(离场不再残留)")
	sfx_t.queue_free()

	# --- 失败原因翻译(LLM.fail_reason)：调试日志据此告诉玩家是哪种失败 ---
	var r_429 = LLM.fail_reason(HTTPRequest.RESULT_SUCCESS, 429, '{"error":{"type":"engine_overloaded_error"}}')
	_check("429" in r_429 and ("过载" in r_429 or "限流" in r_429), "fail_reason: 429→过载/限流")
	var r_401 = LLM.fail_reason(HTTPRequest.RESULT_SUCCESS, 401, '{"error":{"message":"invalid api key"}}')
	_check("401" in r_401 and "鉴权" in r_401, "fail_reason: 401→鉴权失败(key问题)")
	_check("超时" in LLM.fail_reason(HTTPRequest.RESULT_TIMEOUT, 0, ""), "fail_reason: 超时")
	_check("解析失败" in LLM.fail_reason(HTTPRequest.RESULT_SUCCESS, 200, ""), "fail_reason: 200但响应空→解析失败")

	# --- 调试日志行格式(Dbg.format_line) ---
	var ln_fail = Dbg.format_line(2, false, 429, "过载", 0.3)
	_check("第2次" in ln_fail and "FAIL" in ln_fail and "code=429" in ln_fail, "format_line: 失败行含 第2次/FAIL/code")
	var ln_ok = Dbg.format_line(1, true, 200, "正常回复", 4.2)
	_check("OK" in ln_ok and "code=200" in ln_ok, "format_line: 成功行含 OK/code=200")

	print("\n结果: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
