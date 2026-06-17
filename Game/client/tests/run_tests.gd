# 无头测试 runner：godot --headless --path <client> -s res://tests/run_tests.gd
# 退出码 0 = 全过，1 = 有失败。
extends SceneTree

const GameState = preload("res://game/game_state.gd")
const Content = preload("res://game/content.gd")
const Triggers = preload("res://game/triggers.gd")
const Explore = preload("res://game/explore.gd")

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

	print("\n结果: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
