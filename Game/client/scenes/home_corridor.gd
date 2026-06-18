# 老人楼·楼道长廊（色块占位，横版可走）。一排门牌号，702 = 周明远家。
extends Control

const ELEVATOR := "res://scenes/elevator.tscn"
const HOME := "res://scenes/oldman_home.tscn"

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var exit_area: Area2D = $ExitArea
@onready var home_door: Area2D = $HomeDoor
@onready var phone: CanvasLayer = $Phone

func _ready() -> void:
	prompt.visible = false
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从电梯/老人家回来时，落到对应入口锚点

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(home_door):
		prompt.text = "↑ 进入  702 · 周明远家" if Game.state.has_item("home_key") else "702 · 门锁着（需要钥匙）"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "↑ 返回  电梯"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if not event.is_action_pressed("move_up"):
		return
	if _at(home_door):
		if Game.state.has_item("home_key"):
			Game.spawn_point = "from_corridor"   # 老人家里落到门口
			Sfx.play_door()
			get_tree().change_scene_to_file(HOME)
		else:
			Sfx.play_click()
			prompt.text = "门锁着——去警局档案室拿钥匙"
	elif _at(exit_area):
		Game.spawn_point = ""   # 电梯是纯 UI，无需锚点；清掉以防残留
		Sfx.play_door()
		get_tree().change_scene_to_file(ELEVATOR)
