# 主世界 · 宽幅滚动街道(2560 宽) HD-2D：相机跟随玩家横向滚动，远景/雾视差。
# 移动/动画由 Player.tscn 负责；本脚本管相机跟随、雾漂移、门口提示与切场景。
# 门口交互：人物碰撞体叠到 PoliceDoor / CommunityDoor 触发区(Area2D) + 按 W/↑ 进入。
extends Control

const POLICE := "res://scenes/police.tscn"
const COMMUNITY := "res://scenes/community.tscn"
const LEVEL_WIDTH := 2560.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var police_door: Area2D = $PoliceDoor
@onready var community_door: Area2D = $CommunityDoor
@onready var prompt: Label = $Prompt
@onready var toast: Label = $UI/Toast
@onready var phone: CanvasLayer = $Phone   # 可复用手机 UI 实例(phone.tscn)
@onready var intro_fade: ColorRect = $IntroFadeLayer/IntroFade

var toast_tween: Tween
var intro_running := false

func _ready() -> void:
	var intro_from_opening := Game.world_intro_from_opening
	Game.world_intro_from_opening = false
	toast.modulate.a = 0.0
	prompt.visible = false
	intro_fade.visible = intro_from_opening
	intro_fade.color.a = 1.0 if intro_from_opening else 0.0
	Inv.visible = not intro_from_opening
	if intro_from_opening:
		intro_running = true
		player.locked = true
		Music.stop_rain(0.1)
		Music.fade_to(Music.MAIN_WORLD, Music.default_volume_db, 2.0)
		_run_opening_arrival()
	else:
		Music.play_world_with_rain()
	# 看手机时锁住走动（手机自身管显隐/填字，这里只联动锁人）
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从别的场景回来时，落到对应入口锚点
	Game.show_controls_hint_once($UI/Hint)
	_update_prompt()
	# 开局有未读任务 → 只弹文字提示；不播通知音，避免打断开场入场。
	if Game.state.task_unread and not intro_from_opening:
		_show_toast("【周队】新任务已送达")

func _process(_delta: float) -> void:
	# 相机跟随玩家(水平)，夹在关卡两端不露边
	camera.position.x = clampf(player.position.x, 640.0, LEVEL_WIDTH - 640.0)
	camera.position.y = 360.0
	if player.locked or intro_running:
		return
	_update_prompt()

func _near(area: Area2D) -> bool:
	# 只有人物的碰撞体(Player/Col)真正叠到门触发区才算
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _near(police_door):
		prompt.text = "↑ 进入  警察局"
		prompt.visible = true
	elif _near(community_door):
		prompt.text = "→ 进入  晚晴小区"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		# 提示是世界空间 Control，跟随玩家头顶(随相机一起滚)
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

# 警察局是前方建筑→↑/W；晚晴小区在街道最右端→→/D(都容忍 W 兜底)。
func _input(event: InputEvent) -> void:
	if player.locked or intro_running:
		return
	if event.is_action_pressed("move_up") and _near(police_door):
		_enter_door(POLICE, "from_world")
		return
	if (event.is_action_pressed("move_right") or event.is_action_pressed("move_up")) and _near(community_door):
		_enter_door(COMMUNITY, "from_world", "right")

func _enter_door(scene_path: String, entry: String = "", dir: String = "up") -> void:
	Game.spawn_point = entry   # 告诉目标场景：玩家该落在哪个入口锚点
	player.enter_door(dir)
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)

func _show_toast(msg: String) -> void:
	toast.text = msg
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)

func _run_opening_arrival() -> void:
	await get_tree().create_timer(0.8).timeout
	Music.start_rain(Music.rain_volume_db, 2.2)
	await get_tree().create_timer(0.45).timeout
	var fade := create_tween()
	fade.tween_property(intro_fade, "color:a", 0.0, 1.6)
	await fade.finished
	intro_fade.visible = false
	intro_running = false
	player.locked = false
	Inv.visible = true
	if Game.state.task_unread:
		_show_toast("【周队】新任务已送达")
