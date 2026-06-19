extends Control

const OPENING := "res://scenes/opening.tscn"
const ACHIEVE := "res://scenes/achievements.tscn"

@onready var start_btn: Button = $Buttons/StartBtn
@onready var achieve_btn: Button = $Buttons/AchieveBtn
@onready var quit_btn: Button = $Buttons/QuitBtn

func _ready() -> void:
	Music.play_opening()
	start_btn.pressed.connect(func() -> void: Sfx.play_click(); get_tree().change_scene_to_file(OPENING))
	achieve_btn.pressed.connect(func() -> void: Sfx.play_click(); get_tree().change_scene_to_file(ACHIEVE))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	start_btn.grab_focus()
