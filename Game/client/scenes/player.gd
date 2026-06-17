# 主角（可复用）：四向物理移动 + 动画 + 随机待机。被各场景实例化。
# 可走区域由场景里的 Walls(StaticBody2D + 碰撞形状) 决定，撞墙贴滑、可绕障碍 —— 在编辑器里拖墙体即可。
# 动画(detective_frames.tres)：左右走/向下走 → walk_right(向左翻转)；向上走 → walk_up；
#   站立 idle，久站随机插入 adjust_glasses / smoke。
# 进门由场景脚本调 enter_door()：锁住移动 + 播 walk_up；场景随后切场景。
extends CharacterBody2D

@export var speed := 300.0

var locked := false                 # 进门动画期间锁移动
var idle_gap := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle")
	idle_gap = randf_range(4.0, 8.0)

func _physics_process(delta: float) -> void:
	if locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = v * speed
	move_and_slide()
	if v != Vector2.ZERO:
		_move_anim(v)
		idle_gap = randf_range(4.0, 8.0)
	else:
		_idle_behavior(delta)

func _move_anim(v: Vector2) -> void:
	if absf(v.x) > 0.01:                      # 有水平分量 → 侧面走，向左翻转
		sprite.flip_h = v.x < 0.0
		if sprite.animation != "walk_right":
			sprite.play("walk_right")
	elif v.y < 0.0:                           # 纯向上 → 背面走
		if sprite.animation != "walk_up":
			sprite.play("walk_up")
	else:                                     # 纯向下 → 用侧面走动作
		sprite.flip_h = false
		if sprite.animation != "walk_right":
			sprite.play("walk_right")

func _idle_behavior(delta: float) -> void:
	if sprite.animation == "walk_right" or sprite.animation == "walk_up":
		sprite.play("idle")
		idle_gap = randf_range(4.0, 8.0)
		return
	if sprite.animation == "idle":
		idle_gap -= delta
		if idle_gap <= 0.0:
			sprite.play(["adjust_glasses", "smoke"].pick_random())

func _on_anim_finished() -> void:
	if sprite.animation == "adjust_glasses" or sprite.animation == "smoke":
		sprite.play("idle")
		idle_gap = randf_range(4.0, 8.0)

# 场景调用：进门 —— 锁住移动并播放进门(向上)动作
func enter_door() -> void:
	locked = true
	sprite.play("walk_up")
