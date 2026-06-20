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
	_check(Triggers.evaluate(s2, "她早就去世了").is_empty(), "没钥匙不触发第一层")
	s2.add_key("linxiulan")
	_check(Triggers.evaluate(s2, "今天天气如何").is_empty(), "有钥匙无关键词不触发")
	_check(Triggers.evaluate(s2, "她早就去世了，不会回来了") == ["fact"], "持死亡证明+说她去世 触发第一层(她病逝非走丢)")
	s2.reveal("fact")
	_check(Triggers.evaluate(s2, "她去世了").is_empty(), "第一层已揭示不再触发")
	# 第二层真相：需莫忘日志钥匙
	_check(Triggers.evaluate(s2, "是莫忘在骗你").is_empty(), "没莫忘日志不触发第二层")
	s2.add_key("molog")
	_check(Triggers.evaluate(s2, "是莫忘一直说她会回来") == ["complicity"], "持莫忘日志+说莫忘骗他 触发第二层")

	# --- Explore（去邪教版终端线索 -> 钥匙） ---
	var s3 = GameState.new()
	_check(Explore.perform(s3, "archive").get("key") == "linxiulan", "查档案授予 linxiulan")
	_check(Explore.perform(s3, "medical").get("key") == "farewell", "查安葬记录授予 farewell")
	_check(Explore.perform(s3, "molog").get("key") == "molog", "翻莫忘日志授予 molog")
	_check(Explore.perform(s3, "不存在").is_empty(), "未知探索返回空")

	# --- Content（去邪教版设定校验） ---
	_check(Content.TRUTHS.size() == 2, "两层真相")
	var frag_fact := Triggers.fragment_of("fact")
	_check(("去世" in frag_fact) or ("病逝" in frag_fact) or ("不会回来" in frag_fact), "第一层真相=她病逝/不会回来")
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
	_check(Content.TERMINAL_FILES.has("medical") and Content.TERMINAL_FILES["medical"]["grants_key"] == "farewell", "终端·安葬记录授予 farewell")
	_check(("自然死亡" in Content.TERMINAL_FILES["wife"]["text"]), "终端·林秀兰记录=自然死亡")
	for fid in Content.TERMINAL_FILES:
		_check(Content.TERMINAL_FILES[fid]["text"] != "", "终端案卷有内容: " + str(fid))

	# --- 终端查询：每条案卷都有检索关键词（新查询机用） ---
	for fid in Content.TERMINAL_FILES:
		_check(Content.TERMINAL_FILES[fid].has("keywords") and (Content.TERMINAL_FILES[fid]["keywords"] is Array) and not Content.TERMINAL_FILES[fid]["keywords"].is_empty(), "终端案卷有检索关键词: " + str(fid))
	_check("住哪" in Content.TERMINAL_FILES["address"]["keywords"], "住址案卷含'住哪'关键词")
	_check("老婆" in Content.TERMINAL_FILES["wife"]["keywords"], "林秀兰案卷含'老婆'关键词")
	_check("安葬" in Content.TERMINAL_FILES["medical"]["keywords"], "安葬案卷含'安葬'关键词")

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

	# --- 已出示证据 ---
	var s5b = GameState.new()
	_check(s5b.presented_proofs() == "", "未出示时旁白为空")
	s5b.present_evidence("death")
	var p6 := s5b.presented_proofs()
	_check("死亡证明" in p6, "出示死亡证明后旁白含其 proof")
	_check(not ("骨灰" in p6), "未出示安葬记录则旁白不含它")
	s5b.present_evidence("death")  # 去重
	var cnt := 0
	for c in Content.EVIDENCE_CARDS:
		if c["id"] in s5b.presented:
			cnt += 1
	_check(cnt == 1, "重复出示同一张只记一次")

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

	# --- 终局：日志蒙太奇 + 新提醒 + 涌现结局 ---
	_check(Content.MOWANG_HINTS.has("unlock_log"), "新增提醒 unlock_log(拿到手机→去终端解锁)")
	_check(Content.MOWANG_HINTS.has("go_confront"), "新增提醒 go_confront(解锁日志→回审讯对峙)")
	_check(not Content.MOWANG_HINTS.has("confront_molog"), "废弃提醒 confront_molog 已移除")
	# ENDING_SLIDES 已由 AI 涌现结局(裁判 epilogue + ENDING_FALLBACK)取代，不再校验
	_check(str(Content.ENDING_FALLBACK).length() > 0, "结局兜底正文 ENDING_FALLBACK 存在")
	# 固定点题字幕 ENDING 已删除（任何残留 Content.ENDING 引用都会 parse error，编译即校验）
	# 日志蒙太奇：新滑坡("她走丢/在回来的路上")，不再有旧设定"误诊/AI害死"
	var molog_blob := "\n".join(Content.MOWANG_LOG_LINES)
	_check("走丢" in molog_blob or "回来的路上" in molog_blob, "莫忘日志=她走丢了/在回来的路上")
	_check(not ("误诊" in molog_blob), "莫忘日志不再有'误诊'旧设定")
	_check(Content.MOWANG_HINTS.has("ask_farewell"), "提醒含 ask_farewell")

	# --- 莫忘"今天的对话"(道具栏看) + 提醒链:手机→道具栏→终端恢复历史 ---
	_check(Content.MOWANG_TODAY_LINES.size() >= 2, "今天的对话有内容")
	var today_blob := "\n".join(Content.MOWANG_TODAY_LINES)
	_check("莫忘" in today_blob and "今天" in today_blob, "今天的对话含莫忘/今天")
	_check(("锁" in today_blob) or ("读不出" in today_blob), "今天的对话点明更早记录锁住")
	_check(Content.MOWANG_HINTS.has("check_phone") and "道具栏" in str(Content.MOWANG_HINTS["check_phone"]), "拿手机提醒→道具栏")
	_check(("终端" in str(Content.MOWANG_HINTS["unlock_log"])) and ("恢复" in str(Content.MOWANG_HINTS["unlock_log"])), "看完今天提醒→终端恢复历史")

	# --- LLM.parse_reply（客户端直连版，移植自后端 llm.js parseReply） ---
	var r1 = LLM.parse_reply("[sad] 她……只是出门买点菜。 ")
	_check(r1["reply"] == "她……只是出门买点菜。" and r1["emotion"] == "sad" and r1["hint"] == "", "解析句首情绪+去空白")
	var r2 = LLM.parse_reply("[angry]是 AI 害死她的！[[hint:investigate_death]]")
	_check(r2["reply"] == "是 AI 害死她的！" and r2["emotion"] == "angry" and r2["hint"] == "investigate_death", "剥 [[hint:ID]]")
	# end 标签已不再解析（结局改裁判判定）：含 [[end:X]] 的内容当普通文本/忽略
	var r3 = LLM.parse_reply("[sad]她就那么走了。[[end:reveal]]")
	_check(r3["reply"] == "她就那么走了。[[end:reveal]]" or (not r3.has("end") or r3.get("end","") == ""), "end 标签不再产出(当文本或丢弃)")
	var r5 = LLM.parse_reply("[angry]是 AI 害的！[[hint:visit_community]][[end:ready]]")
	_check(r5["reply"] != "" and r5["hint"] == "visit_community" and (not r5.has("end") or r5.get("end","") == ""), "hint 仍剥，end 不再产出")
	var r6 = LLM.parse_reply("[angry]你们懂什么！\n\n[calm]好吧，我承认。")
	_check(r6["reply"] == "你们懂什么！\n\n好吧，我承认。" and r6["emotion"] == "angry", "中段情绪标签也剥,取第一个")
	_check(LLM.parse_reply("[happy]你好")["reply"] == "[happy]你好", "非法情绪标签原样保留")
	var r8 = LLM.parse_reply("我就……记记日常。   [[hint:protecting_app]]")
	_check(r8["reply"] == "我就……记记日常。" and r8["hint"] == "protecting_app", "尾部 hint 剥净不残留")
	# parse_reply 不再产出 end 字段（结局改裁判判定，C2）
	var pr := LLM.parse_reply("[sad]她出门了，一会儿就回来。[[hint:investigate_death]]")
	_check(pr["emotion"] == "sad", "情绪仍解析")
	_check(pr["hint"] == "investigate_death", "hint 仍解析")
	_check(not pr.has("end") or str(pr.get("end","")) == "", "不再产出 end 字段")

	# 终局 roleplay 提示词不含结局正文分隔符
	_check(not ("===结局===" in LLM.FINALE_SYSTEM_PROMPT), "终局roleplay不含结局正文分隔符")

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
	sfx_t.stop_typing()                # 修复动作:离场统一停(现在带淡出避爆音,异步)
	await create_timer(0.25).timeout   # 等淡出完成
	_check(not sfx_t._typing_player.playing, "stop_typing(淡出后)→循环停下(离场不再残留)")
	sfx_t.queue_free()

	# --- 提示词新设定 ---
	_check("走丢" in LLM.SYSTEM_PROMPT or "回来" in LLM.SYSTEM_PROMPT, "人设=她会回来/走丢")
	_check(not ("误诊" in LLM.SYSTEM_PROMPT), "人设不再有AI误诊旧设定")
	_check(not ("莫忘说" in LLM.SYSTEM_PROMPT), "人设不再让老头嘴里说'莫忘说…'(防剧透:莫忘靠玩家挖出)")
	_check(not ("[[end" in LLM.FINALE_SYSTEM_PROMPT), "终局roleplay不再让老头吐end标签")

	# --- 失败原因翻译(LLM.fail_reason)：调试日志据此告诉玩家是哪种失败 ---
	var r_429 = LLM.fail_reason(HTTPRequest.RESULT_SUCCESS, 429, '{"error":{"type":"engine_overloaded_error"}}')
	_check("429" in r_429 and ("过载" in r_429 or "限流" in r_429), "fail_reason: 429→过载/限流")
	var r_401 = LLM.fail_reason(HTTPRequest.RESULT_SUCCESS, 401, '{"error":{"message":"invalid api key"}}')
	_check("401" in r_401 and "鉴权" in r_401, "fail_reason: 401→鉴权失败(key问题)")
	_check("超时" in LLM.fail_reason(HTTPRequest.RESULT_TIMEOUT, 0, ""), "fail_reason: 超时")
	_check("解析失败" in LLM.fail_reason(HTTPRequest.RESULT_SUCCESS, 200, ""), "fail_reason: 200但响应空→解析失败")

	# --- 网页版直连 Moonshot(已验证 Moonshot 允许浏览器 CORS)；headers 带 key ---
	var _hdr := LLM.headers()
	_check("Content-Type: application/json" in _hdr, "headers 含 Content-Type")
	_check("Authorization: Bearer " in "\n".join(_hdr), "headers() 带 Authorization(直连 Moonshot)")

	# --- 终端查询：本地关键词兜底匹配 LLM.terminal_local_match ---
	_check(LLM.terminal_local_match("他住哪") == "address", "本地匹配: 他住哪→address")
	_check(LLM.terminal_local_match("他老婆呢") == "wife", "本地匹配: 他老婆→wife")
	_check(LLM.terminal_local_match("安葬在哪里") == "medical", "本地匹配: 安葬→medical")
	_check(LLM.terminal_local_match("周明远是谁") == "zhou", "本地匹配: 周明远→zhou")
	_check(LLM.terminal_local_match("今天天气怎么样") == "", "本地匹配: 无关问题→空")
	_check(LLM.terminal_local_match("") == "", "本地匹配: 空输入→空")

	# --- 终端查询：从模型输出抠合法 id LLM.parse_terminal_result ---
	_check(LLM.parse_terminal_result("zhou") == "zhou", "解析: 裸 id")
	_check(LLM.parse_terminal_result("[wife]") == "wife", "解析: 方括号 id")
	_check(LLM.parse_terminal_result("id: address") == "address", "解析: 带前缀 id")
	_check(LLM.parse_terminal_result("应该是 medical 这条") == "medical", "解析: 句中 id")
	_check(LLM.parse_terminal_result("NONE") == "", "解析: NONE→空")
	_check(LLM.parse_terminal_result("没有匹配的记录") == "", "解析: 自然语言无→空")
	_check(LLM.parse_terminal_result("xyz") == "", "解析: 非法 id→空")
	_check(LLM.parse_terminal_result("") == "", "解析: 空→空")

	# --- 调试日志行格式(Dbg.format_line) ---
	var ln_fail = Dbg.format_line(2, false, 429, "过载", 0.3)
	_check("第2次" in ln_fail and "FAIL" in ln_fail and "code=429" in ln_fail, "format_line: 失败行含 第2次/FAIL/code")
	var ln_ok = Dbg.format_line(1, true, 200, "正常回复", 4.2)
	_check("OK" in ln_ok and "code=200" in ln_ok, "format_line: 成功行含 OK/code=200")

	# --- 设置: API key 运行时覆盖(设置里填了优先,没填用内置) ---
	LLM.set_runtime_key("")
	_check(LLM.active_key() == LLM.API_KEY, "没填→用内置 key")
	LLM.set_runtime_key("sk-test-123")
	_check(LLM.active_key() == "sk-test-123", "填了→用填的 key")
	var has_bearer := false
	for line in LLM.headers():
		if line == "Authorization: Bearer sk-test-123":
			has_bearer = true
	_check(has_bearer, "headers 用运行时 key")
	LLM.set_runtime_key("  sk-trim  ")
	_check(LLM.active_key() == "sk-trim", "key 去首尾空格")
	# key 指纹(诊断 401 用哪个 key)
	LLM.set_runtime_key("")
	_check("占位符" in LLM.key_fingerprint(), "没填→指纹标出占位符未注入")
	LLM.set_runtime_key("sk-abcdef123456")
	var fp = LLM.key_fingerprint()
	_check("设置key" in fp and "len=" in fp and "sk-abc" in fp, "填了→指纹显示来源/长度/前缀")
	LLM.set_runtime_key("")   # 复原，别影响其它测试

	# --- 证据手牌 ---
	_check(Content.EVIDENCE_CARDS.size() == 4, "4 张证据牌")
	var card_keys := {}
	for c in Content.EVIDENCE_CARDS:
		card_keys[c["id"]] = c["key"]
	_check(card_keys.get("death") == "linxiulan", "死亡证明牌挂 linxiulan")
	_check(card_keys.get("farewell") == "farewell", "安葬记录牌挂 farewell")
	_check(card_keys.get("molog") == "molog", "莫忘日志牌挂 molog")
	_check(card_keys.get("photo") == "photo", "合照牌挂 photo")
	_check(str(Content.ENDING_FALLBACK).length() > 0, "有结局兜底正文")

	# --- 设置: 背景音乐开关(独立 Music 总线静音/取消静音) ---
	var mus = load("res://autoload/music.gd").new()
	get_root().add_child(mus)
	await process_frame   # _ready → _setup_bus 建 "Music" 总线
	_check(mus.is_enabled(), "音乐默认开")
	mus.set_enabled(false)
	_check(not mus.is_enabled(), "关→Music 总线静音")
	mus.set_enabled(true)
	_check(mus.is_enabled(), "开→取消静音")
	mus.queue_free()

	# --- 裁判 parse_director + build_director_messages ---
	var d1 := LLM.parse_director('{"end": true, "kind": "truth", "epilogue": "他没再说话。"}')
	_check(d1["end"] == true and d1["kind"] == "truth" and "没再说话" in d1["epilogue"], "裁判正常JSON解析")
	var d2 := LLM.parse_director("这不是JSON")
	_check(d2["end"] == false, "裁判畸形输出当不结束")
	var d3 := LLM.parse_director('前缀 {"end": false, "kind":"", "epilogue":""} 后缀')
	_check(d3["end"] == false, "裁判能从噪声里抠出JSON且不结束")
	var dm := LLM.build_director_messages([{"role":"user","content":"她去世了"}], "（侦探出示了死亡证明）", 4)
	_check(dm.size() >= 2 and dm[0]["role"] == "system", "裁判messages带系统提示")

	# --- 称号评定 ---
	_check(LLM.parse_title("「真相揭穿者」") == "真相揭穿者", "剥书名/引号包裹")
	_check(LLM.parse_title("固执的等待者。").length() <= 10, "截断到≤10字")
	_check(LLM.parse_title("下一个莫忘\n（解释...）") == "下一个莫忘", "只取第一行")
	_check(LLM.parse_title("   ") == "", "空白→空串")
	_check(LLM.parse_title("一二三四五六七八九十十一十二") == "一二三四五六七八九十", "超10字截断到10")
	var tm := LLM.build_title_messages([{"role":"user","content":"她去世了"}], "truth")
	_check(tm.size() == 2 and tm[0]["role"] == "system" and "truth" in tm[1]["content"], "称号messages带提示+结局类型")

	# --- 终端查询：检索员提示词与请求构建 ---
	_check(LLM.TERMINAL_SYSTEM_PROMPT.length() > 0, "终端检索员提示词存在")
	_check(("NONE" in LLM.TERMINAL_SYSTEM_PROMPT), "提示词要求无匹配时回 NONE")
	var tmsgs = LLM.build_terminal_messages("他住哪")
	_check(tmsgs.size() == 2 and tmsgs[0]["role"] == "system" and tmsgs[1]["role"] == "user", "终端messages=system+user")
	_check(tmsgs[1]["content"] == "他住哪", "终端user消息=玩家原句")
	_check(("address" in tmsgs[0]["content"]) and ("zhou" in tmsgs[0]["content"]), "系统消息含档案id清单")
	var tbody = LLM.terminal_request_body("他住哪")
	var tparsed = JSON.parse_string(tbody)
	_check(typeof(tparsed) == TYPE_DICTIONARY and tparsed.has("messages") and tparsed.has("model"), "终端请求体含 model/messages")

	# --- Titles 称号收藏 ---
	var Tt = preload("res://game/titles.gd")
	var tt = Tt.new()
	_check(tt._register("真相揭穿者"), "首次注册称号=新")
	_check(not tt._register("真相揭穿者"), "重复注册同名=非新(去重)")
	_check(not tt._register("  真相揭穿者  "), "去空格后仍判重复")
	_check(not tt._register(""), "空称号不注册")
	_check(tt.count() == 1, "去重后只 1 个")
	tt._register("下一个莫忘")
	_check(tt.all_titles() == ["真相揭穿者", "下一个莫忘"], "按获得顺序返回")
	# 存档 round-trip(临时路径,不污染真实存档)
	var tmp := "user://_test_ach.cfg"
	tt._save_to(tmp)
	var tt2 = Tt.new()
	tt2._load_from(tmp)
	_check(tt2.all_titles() == ["真相揭穿者", "下一个莫忘"], "存档读档 round-trip 一致")
	_check(not tt2._register("真相揭穿者"), "读档后仍去重")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# --- 证据列表:key→证据卡查询 ---
	_check(Content.evidence_card_for_key("linxiulan").get("id", "") == "death", "key linxiulan→death 卡")
	_check(Content.evidence_card_for_key("farewell").get("id", "") == "farewell", "key farewell→farewell 卡")
	_check(Content.evidence_card_for_key("photo").get("id", "") == "photo", "key photo→photo 卡")
	_check(Content.evidence_card_for_key("molog").get("id", "") == "molog", "key molog→molog 卡")
	_check(Content.evidence_card_for_key("home_address").is_empty(), "非证据 key home_address→空字典")
	_check(Content.evidence_card_for_key("").is_empty(), "空 key→空字典")
	# --- 证据列表:toast 去重 ---
	var es := GameState.new()
	_check(es.evidence_seen.is_empty(), "新局 evidence_seen 为空")
	_check(es.mark_evidence_seen("death") == true, "首次标记 death→true")
	_check(es.mark_evidence_seen("death") == false, "重复标记 death→false(去重)")
	_check(es.mark_evidence_seen("") == false, "空 card_id→false")
	_check(es.evidence_howto_shown == false, "新局 证据出示提醒未弹")
	_check(es.mark_evidence_howto() == true, "首次进审讯有证据→弹出示提醒")
	_check(es.mark_evidence_howto() == false, "证据出示提醒只弹一次")

	# --- 隐藏电话线：触发检测 + 解锁门控 ---
	_check(LLM.asks_why_calls("你为什么老打电话") == true, "问为什么打电话→解锁命中")
	_check(LLM.asks_why_calls("你给谁打电话啊") == true, "打给谁→解锁命中")
	_check(LLM.asks_why_calls("今天天气怎么样") == false, "无关→不解锁")
	_check(LLM.asks_how_connected("你是怎么打通的") == true, "问怎么打通→触发命中")
	_check(LLM.asks_how_connected("电话接通了吗") == true, "接通了吗→触发命中")
	_check(LLM.asks_how_connected("她在哪") == false, "无关→不触发")
	# "当场打给她看/证明给我看"这类挑战也应触发(老头收尾台词正是"我拨给你看")
	_check(LLM.asks_how_connected("给我看他和他妻子打电话") == true, "给我看他打电话→触发")
	_check(LLM.asks_how_connected("给我看看他打电话") == true, "给我看看他打电话→触发")
	_check(LLM.asks_how_connected("你打给她看看") == true, "打给她看看→触发")
	_check(LLM.asks_how_connected("你当面打给她") == true, "当面打给她→触发")
	# 但只是问"为什么打电话"仍只解锁、不触发；提到"看"但与打电话无关也不触发
	_check(LLM.asks_how_connected("他为什么打电话") == false, "问为什么打电话→不触发(只解锁)")
	_check(LLM.asks_how_connected("给我看死亡证明") == false, "给我看证据→不触发电话结局")
	var ps := GameState.new()
	_check(ps.phone_line_unlocked == false, "新局 phone_line_unlocked=false")
	# 终端聊天记录跨场景保留(离开终端室再回来仍在)
	_check(ps.terminal_chat.is_empty(), "新局 终端聊天记录为空")
	ps.add_terminal_chat("你", "他住哪")
	ps.add_terminal_chat("终端", "晚晴小区 2 号楼")
	_check(ps.terminal_chat.size() == 2, "终端聊天追加两条")
	_check(ps.terminal_chat[0]["who"] == "你" and ps.terminal_chat[1]["msg"] == "晚晴小区 2 号楼", "终端聊天记录内容正确")
	_check((ps.phone_line_unlocked and LLM.asks_how_connected("怎么打通的")) == false, "未解锁→不触发")
	ps.phone_line_unlocked = true
	_check((ps.phone_line_unlocked and LLM.asks_how_connected("怎么打通的")) == true, "解锁后→触发")

	# --- 隐藏电话线：提示词与文案 ---
	_check(LLM.PHONE_EPILOGUE_PROMPT.length() > 0, "电话结局旁白提示词存在")
	_check(str(Content.ENDING_PHONE_FALLBACK).length() > 0, "电话结局兜底文案存在")
	_check(("电话" in LLM.SYSTEM_PROMPT) and ("打通" in LLM.SYSTEM_PROMPT), "人设含电话元素")
	_check(("电话" in LLM.FINALE_SYSTEM_PROMPT) and ("打通" in LLM.FINALE_SYSTEM_PROMPT), "终局人设含电话元素")
	var pe = LLM.phone_epilogue_request_body([{"role": "user", "content": "hi"}])
	var pep = JSON.parse_string(pe)
	_check(typeof(pep) == TYPE_DICTIONARY and pep.has("messages") and pep.has("model"), "电话epilogue请求体含model/messages")
	_check(LLM.parse_phone_epilogue("  电话接通了。  ") == "电话接通了。", "解析epilogue剥首尾空白")

	print("\n结果: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
