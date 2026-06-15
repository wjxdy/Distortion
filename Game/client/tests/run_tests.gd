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
	_check(not s.is_revealed("wife"), "初始未揭示")
	s.reveal("wife")
	_check(s.is_revealed("wife"), "揭示后为真")
	s.add_to_history("user", "你好")
	_check(s.history.size() == 1 and s.history[0]["role"] == "user", "历史可追加")

	# --- Triggers ---
	var s2 = GameState.new()
	_check(Triggers.evaluate(s2, "林秀兰是谁？").is_empty(), "没钥匙不触发")
	s2.add_key("linxiulan")
	_check(Triggers.evaluate(s2, "今天天气如何").is_empty(), "有钥匙无关键词不触发")
	_check(Triggers.evaluate(s2, "蓝裙子那个人是谁") == ["wife"], "有钥匙且命中关键词触发")
	s2.reveal("wife")
	_check(Triggers.evaluate(s2, "林秀兰").is_empty(), "已揭示不再触发")

	# --- Explore ---
	var s3 = GameState.new()
	var r = Explore.perform(s3, "archive")
	_check(r.has("key") and r["key"] == "linxiulan", "探索授予钥匙并返回")
	_check(s3.has_key("linxiulan"), "探索后状态记住钥匙")
	_check(Explore.perform(s3, "不存在").is_empty(), "未知探索返回空")

	print("\n结果: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
