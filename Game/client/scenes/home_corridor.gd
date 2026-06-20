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
	Game.show_controls_hint_once($Hint)

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(home_door):
		prompt.text = "↑ 进入  702 · 周明远家" if Game.state.has_item("home_key") else "702 · 门锁着（去档案室拿钥匙）"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "← 返回  电梯"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

# 门按 W/↑ 进出；老人家门需钥匙
func _input(event: InputEvent) -> void:
	if player.locked:
		return
	# 返回电梯在左边→只按 ←/A
	if event.is_action_pressed("move_left") and _at(exit_area):
		_go(ELEVATOR, "", "left")
		return
	# 老人家门在前方→↑/W
	if event.is_action_pressed("move_up") and _at(home_door):
		if Game.state.has_item("home_key"):
			_go(HOME, "from_corridor")
		else:
			Sfx.play_click()
			prompt.text = "门锁着——去警局档案室拿钥匙"

func _go(scene_path: String, entry: String, dir: String = "up") -> void:
	Game.spawn_point = entry
	player.enter_door(dir)
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
