# 老人楼·楼道长廊（色块占位，横版可走）。一排门牌号，702 = 周明远家。
extends Control

const ELEVATOR := "res://scenes/elevator.tscn"
const HOME := "res://scenes/oldman_home.tscn"

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var exit_area: Area2D = $ExitArea
@onready var home_door: Area2D = $HomeDoor
@onready var phone: CanvasLayer = $Phone

var _doors_armed := false   # 反跳保护：先离开门区才允许踩门跳转

func _ready() -> void:
	prompt.visible = false
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从电梯/老人家回来时，落到对应入口锚点

func _process(_delta: float) -> void:
	if player.locked:
		return
	if not _doors_armed:
		if not _on_any_door():
			_doors_armed = true
	elif _check_doors():
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _on_any_door() -> bool:
	return _at(exit_area) or _at(home_door)

func _check_doors() -> bool:
	if _at(exit_area):
		_go(ELEVATOR, ""); return true
	# 老人家门：踩到且有钥匙才进；没钥匙不跳(提示门锁着)
	if _at(home_door) and Game.state.has_item("home_key"):
		_go(HOME, "from_corridor"); return true
	return false

func _update_prompt() -> void:
	if _at(home_door):
		prompt.text = "▶ 702 · 周明远家" if Game.state.has_item("home_key") else "702 · 门锁着（去档案室拿钥匙）"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "▶ 电梯"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

func _go(scene_path: String, entry: String) -> void:
	Game.spawn_point = entry
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
