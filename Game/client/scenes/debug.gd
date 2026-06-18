# 调试模块（autoload Dbg）。F12 或 ` 键开关一个右上角日志面板，显示每次大模型请求的
# 成功/失败 + HTTP 码 + 原因 + 耗时，方便排查"老头为什么秒回点点点"。
# 默认隐藏、不打扰玩家；发布包里也在，但不按键看不到。请求方(审讯室)调 Dbg.log_req(...) 写日志。
extends CanvasLayer

const MAX_LINES := 120

@onready var panel: ColorRect = $Panel
@onready var log_label: RichTextLabel = $Panel/Log

var _lines: Array = []

func _ready() -> void:
	panel.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12 or event.keycode == KEY_QUOTELEFT:
			panel.visible = not panel.visible
			if panel.visible:
				log_label.text = _render()
			get_viewport().set_input_as_handled()

# 请求方每次(尝试)结束调用，写一行日志。
# attempt=第几次尝试, ok=是否成功, code=HTTP状态, reason=原因/动作, elapsed=耗时秒。
func log_req(attempt: int, ok: bool, code: int, reason: String, elapsed: float) -> void:
	_lines.append(format_line(attempt, ok, code, reason, elapsed))
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	if panel and panel.visible:
		log_label.text = _render()

func _render() -> String:
	return "(暂无请求)" if _lines.is_empty() else "\n".join(_lines)

# 纯函数：拼一行带颜色(bbcode)的日志。抽出来便于单测。
static func format_line(attempt: int, ok: bool, code: int, reason: String, elapsed: float) -> String:
	var t := Time.get_time_string_from_system()
	var mark := "[color=#7fff7f]✓OK[/color]" if ok else "[color=#ff7f7f]✗FAIL[/color]"
	return "%s 第%d次 %s code=%d %.1fs  %s" % [t, attempt, mark, code, elapsed, reason]
