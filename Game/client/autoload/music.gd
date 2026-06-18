# 全局背景音乐单例（autoload 名 Music）。场景只负责声明想播放哪首，淡入淡出与防重复由这里统一管。
extends Node

const MAIN_WORLD := "res://audio/bgm/main_world.ogg"
const RAIN_WORLD := "res://audio/ambience/rain_world.ogg"

@export var default_volume_db := -13.0
@export var fade_seconds := 0.8
@export var rain_volume_db := -13.0
@export var rain_fade_seconds := 2.0

var current_path := ""
var _player: AudioStreamPlayer
var _fade_tween: Tween
var _rain_player: AudioStreamPlayer
var _rain_tween: Tween

func _ready() -> void:
	_ensure_player()

func play_world() -> void:
	fade_to(MAIN_WORLD)

func play_world_with_rain() -> void:
	play_world()
	start_rain()

func fade_to(path: String, target_volume_db := default_volume_db) -> void:
	_ensure_player()
	if current_path == path and _player.playing:
		return
	var stream := load(path)
	if stream == null:
		push_warning("BGM not found: " + path)
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if _player.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", -80.0, fade_seconds * 0.5)
		_fade_tween.tween_callback(func() -> void: _start_stream(path, stream, target_volume_db))
		_fade_tween.tween_property(_player, "volume_db", target_volume_db, fade_seconds * 0.5)
	else:
		_start_stream(path, stream, target_volume_db)

func stop() -> void:
	_ensure_player()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if not _player.playing:
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -80.0, fade_seconds)
	_fade_tween.tween_callback(func() -> void:
		_player.stop()
		current_path = ""
	)

func start_rain(target_volume_db := rain_volume_db) -> void:
	_ensure_rain_player()
	if _rain_tween and _rain_tween.is_valid():
		_rain_tween.kill()
	if _rain_player.stream == null:
		var stream := load(RAIN_WORLD)
		if stream == null:
			push_warning("Rain ambience not found: " + RAIN_WORLD)
			return
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_rain_player.stream = stream
	if not _rain_player.playing:
		_rain_player.volume_db = -80.0
		_rain_player.play()
	_rain_tween = create_tween()
	_rain_tween.tween_property(_rain_player, "volume_db", target_volume_db, rain_fade_seconds)

func stop_rain() -> void:
	_ensure_rain_player()
	if _rain_tween and _rain_tween.is_valid():
		_rain_tween.kill()
	if not _rain_player.playing:
		return
	_rain_tween = create_tween()
	_rain_tween.tween_property(_rain_player, "volume_db", -80.0, rain_fade_seconds * 0.5)
	_rain_tween.tween_callback(_rain_player.stop)

func _ensure_player() -> void:
	if _player:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	add_child(_player)

func _ensure_rain_player() -> void:
	if _rain_player:
		return
	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainPlayer"
	add_child(_rain_player)

func _start_stream(path: String, stream: AudioStream, target_volume_db: float) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	current_path = path
	_player.stream = stream
	_player.volume_db = target_volume_db
	_player.play()
