# 老人房间（色块占位，可走）。两件关键证物：墙上合照、床头手机。
# 查合照 → 显示文案 + 发 photo 钥匙；查手机 → 打开「莫忘日志滑坡」逐条翻，翻完发 molog 钥匙
# + 莫忘提醒"回审讯做对峙"(第二层真相入口)。
extends Control

const CORRIDOR := "res://scenes/home_corridor.tscn"
const Content = preload("res://game/content.gd")

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var info: Label = $Info
@onready var phone: CanvasLayer = $Phone
@onready var photo_area: Area2D = $PhotoArea
@onready var phone_area: Area2D = $PhoneArea
@onready var exit_area: Area2D = $ExitArea

func _ready() -> void:
	prompt.visible = false
	info.visible = false
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从楼道进来时，落到门口锚点

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(photo_area):
		prompt.text = "空格  查看合照"
		prompt.visible = true
	elif _at(phone_area):
		prompt.text = "空格  查看手机"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "↑ 离开"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

# 门按 W/↑ 进出；物品(合照/手机)按空格查看
func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if event.is_action_pressed("move_up") and _at(exit_area):
		_go(CORRIDOR, "from_home")
	elif event.is_action_pressed("ui_select"):
		if _at(photo_area):
			_examine("photo")
		elif _at(phone_area):
			_take_phone()

func _go(scene_path: String, entry: String) -> void:
	Game.spawn_point = entry
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)

func _examine(id: String) -> void:
	Sfx.play_click()
	var e = Content.HOME_EVIDENCE[id]
	info.text = str(e["text"])
	info.visible = true
	var k := str(e.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)

# 查老人手机 → 只拿到手机道具 + 莫忘提醒去警局终端解锁日志(日志在终端看)
func _take_phone() -> void:
	Sfx.play_click()
	Game.state.add_item("oldman_phone")   # 老人手机进道具栏
	Inv.refresh()
	info.text = "你拿起床头的手机——屏幕还亮着「莫忘」。在道具栏点开它，看看他和那个 AI 说了什么。"
	info.visible = true
	if Game.state.fire_hint("check_phone", str(Content.MOWANG_HINTS["check_phone"])):
		phone.notify_hint()
