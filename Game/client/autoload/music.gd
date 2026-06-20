# 全局背景音乐单例（autoload 名 Music）。场景只负责声明想播放哪首，淡入淡出与防重复由这里统一管。
extends Node

const MAIN_WORLD := "res://audio/bgm/main_world.ogg"
const OPENING_SLIDES := "res://audio/bgm/opening_slides.mp3"
const RAIN_WORLD := "res://audio/ambience/rain_world.ogg"
const POLICE_STATION := "res://audio/ambience/police_station_ambience.mp3"
const MUSIC_BUS := "Music"   # BGM+雨声走这条独立总线，设置里开关=静音它(不影响音效)

@export var default_volume_db := -13.0
@export var fade_seconds := 0.8
@export var rain_volume_db := -13.0
@export var rain_fade_seconds := 2.0
@export var police_ambience_volume_db := -15.0

var current_path := ""
var _player: AudioStreamPlayer
var _fade_tween: Tween
var _rain_player: AudioStreamPlayer
var _rain_tween: Tween

func _ready() -> void:
	_setup_bus()
	set_enabled(true)
	_ensure_player()

# "Music" 总线由静态 default_bus_layout.tres 在启动时提供(Master + Music)。
# ⚠️ 禁止运行时 AudioServer.add_bus()：实测 Godot 4.6.3 网页版下运行时新建总线
# 会让整个音频输出哑掉(连 Master 也哑)。这里只兜底：万一布局没加载到 Music,
# 才补建一条(桌面端安全;网页端正常情况下走静态布局不会进这分支)。
func _setup_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, "Master")

# 设置界面调：开关背景音乐(静音/取消静音整条 Music 总线，音效不受影响)。
func set_enabled(on: bool) -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx != -1:
		AudioServer.set_bus_mute(idx, not on)

func is_enabled() -> bool:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	return idx == -1 or not AudioServer.is_bus_mute(idx)

func play_opening() -> void:
	stop_rain()
	fade_to(OPENING_SLIDES, default_volume_db, 1.4)

func play_world() -> void:
	fade_to(MAIN_WORLD)

func play_world_with_rain() -> void:
	play_world()
	start_rain()

func play_police_ambience() -> void:
	stop_rain(0.6)
	fade_to(POLICE_STATION, police_ambience_volume_db, 1.2)

func fade_to(path: String, target_volume_db := default_volume_db, duration := fade_seconds) -> void:
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
		_fade_tween.tween_property(_player, "volume_db", -80.0, duration * 0.5)
		_fade_tween.tween_callback(func() -> void: _start_stream(path, stream, target_volume_db))
		_fade_tween.tween_property(_player, "volume_db", target_volume_db, duration * 0.5)
	else:
		_start_stream(path, stream, -80.0)
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", target_volume_db, duration)

func stop(duration := fade_seconds) -> void:
	_ensure_player()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if not _player.playing:
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -80.0, duration)
	_fade_tween.tween_callback(func() -> void:
		_player.stop()
		current_path = ""
	)

func start_rain(target_volume_db := rain_volume_db, duration := rain_fade_seconds) -> void:
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
	_rain_tween.tween_property(_rain_player, "volume_db", target_volume_db, duration)

func stop_rain(duration := rain_fade_seconds * 0.5) -> void:
	_ensure_rain_player()
	if _rain_tween and _rain_tween.is_valid():
		_rain_tween.kill()
	if not _rain_player.playing:
		return
	_rain_tween = create_tween()
	_rain_tween.tween_property(_rain_player, "volume_db", -80.0, duration)
	_rain_tween.tween_callback(_rain_player.stop)

func _ensure_player() -> void:
	if _player:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	_player.bus = MUSIC_BUS
	add_child(_player)

func _ensure_rain_player() -> void:
	if _rain_player:
		return
	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainPlayer"
	_rain_player.bus = MUSIC_BUS
	add_child(_rain_player)

func _start_stream(path: String, stream: AudioStream, target_volume_db: float) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	current_path = path
	_player.stream = stream
	_player.volume_db = target_volume_db
	_player.play()
