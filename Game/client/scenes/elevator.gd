# 老人楼电梯界面（色块占位 UI）。点对应楼层进楼道；老人住 7 层，点错给反馈。
extends Control

const COMMUNITY := "res://scenes/community.tscn"
const CORRIDOR := "res://scenes/home_corridor.tscn"
const OLD_FLOOR := 7

@onready var info: Label = $Info
@onready var back_btn: Button = $BackBtn

func _ready() -> void:
	back_btn.pressed.connect(_back)
	for f in [3, 5, 7, 9]:
		var b := get_node("Floors/F%d" % f) as Button
		b.pressed.connect(_pick.bind(f))

func _pick(floor_num: int) -> void:
	Sfx.play_click()
	if floor_num == OLD_FLOOR:
		Sfx.play_door()
		get_tree().change_scene_to_file(CORRIDOR)
	else:
		info.text = "%d 层……不是他家。（他住 7 层）" % floor_num

func _back() -> void:
	Sfx.play_door()
	get_tree().change_scene_to_file(COMMUNITY)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
