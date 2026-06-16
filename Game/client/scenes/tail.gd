@tool
extends Control
class_name SpeechTail
## 气泡的"尖尖"，编辑器里可见可调。dir = 朝向(up/down)，color = 配气泡底色。
## 拉大/缩小这个节点 = 改尖尖大小；放在气泡哪条边 = 它从哪边伸出。

@export_enum("up", "down") var dir: String = "down":
	set(value):
		dir = value
		queue_redraw()

@export var color: Color = Color(0.17, 0.16, 0.14, 0.95):
	set(value):
		color = value
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var pts: PackedVector2Array
	if dir == "down":
		pts = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.5, h)])
	else:
		pts = PackedVector2Array([Vector2(0, h), Vector2(w, h), Vector2(w * 0.5, 0)])
	draw_colored_polygon(pts, color)
