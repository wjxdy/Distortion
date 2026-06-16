# 终端室（占位）：将来在这里查警局电脑、问警局 AI、调老人档案/医疗记录/莫忘日志。
# 现在只是占位屏 + 返回走廊（点按钮或按 Esc 返回）。
extends Control

const POLICE := "res://scenes/police.tscn"

@onready var back_btn: Button = $Center/VBox/BackBtn

func _ready() -> void:
	back_btn.pressed.connect(_back)

func _back() -> void:
	Sfx.play_click()
	get_tree().change_scene_to_file(POLICE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
