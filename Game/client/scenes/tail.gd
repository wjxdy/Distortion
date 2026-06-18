@tool
extends Control
class_name SpeechTail
## 气泡的"尖尖"，编辑器里可见可调。dir = 朝向(up/down)，color = 配气泡边框色。
## 拉大/缩小这个节点 = 改尖尖大小；放在气泡哪条边 = 它从哪边伸出。

@export_enum("up", "down") var dir: String = "down":
	set(value):
		dir = value
		queue_redraw()

@export var color: Color = Color(0.86, 0.88, 0.9, 0.95):
	set(value):
		color = value
		queue_redraw()

@export_range(1.0, 4.0, 1.0) var line_width: float = 2.0:
	set(value):
		line_width = value
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if dir == "down":
		var tip := Vector2(w * 0.5, h)
		draw_line(Vector2(0, 0), tip, color, line_width, false)
		draw_line(Vector2(w, 0), tip, color, line_width, false)
	else:
		var tip := Vector2(w * 0.5, 0)
		draw_line(Vector2(0, h), tip, color, line_width, false)
		draw_line(Vector2(w, h), tip, color, line_width, false)
