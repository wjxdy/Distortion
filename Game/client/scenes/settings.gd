# 设置界面（autoload Settings）。按 ESC 开/关；可开关背景音乐、设置 API Key。
# 设置存到 user://settings.cfg，下次启动自动恢复并应用(音乐总线静音、LLM 运行时 key)。
# 静态结构都在 settings.tscn 里(可拖)。
extends CanvasLayer

const LLM = preload("res://game/llm.gd")   # 运行时 key 覆盖
const CFG_PATH := "user://settings.cfg"

@onready var dim: ColorRect = $Dim
@onready var panel: ColorRect = $Panel
@onready var music_check: CheckButton = $Panel/MusicCheck
@onready var api_input: LineEdit = $Panel/ApiInput
@onready var save_btn: Button = $Panel/SaveBtn
@onready var saved_hint: Label = $Panel/SavedHint
@onready var close_btn: Button = $Panel/CloseBtn

var _music_on := true
var _api_key := ""

func _ready() -> void:
	_load()
	Music.set_enabled(_music_on)     # 应用已存设置
	LLM.set_runtime_key(_api_key)
	music_check.button_pressed = _music_on
	api_input.text = _api_key
	saved_hint.visible = false
	_set_shown(false)
	music_check.toggled.connect(_on_music_toggled)
	save_btn.pressed.connect(_on_save_key)
	api_input.text_submitted.connect(func(_t: String) -> void: _on_save_key())
	close_btn.pressed.connect(close)

# ESC 开/关设置(返回上一层一律靠场景里的返回按钮，ESC 只管设置)。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if panel.visible:
		close()
	else:
		open()

func open() -> void:
	Sfx.play_click()
	music_check.button_pressed = Music.is_enabled()
	api_input.text = _api_key
	saved_hint.visible = false
	_set_shown(true)

func close() -> void:
	_apply_key()   # 关闭也保存当前填的 key，免得粘贴了忘点「保存」导致没生效
	Sfx.play_click()
	_set_shown(false)

func _set_shown(b: bool) -> void:
	dim.visible = b
	panel.visible = b

func _on_music_toggled(on: bool) -> void:
	_music_on = on
	Music.set_enabled(on)
	_save()

func _apply_key() -> void:
	_api_key = api_input.text.strip_edges()
	LLM.set_runtime_key(_api_key)
	_save()

func _on_save_key() -> void:
	_apply_key()
	saved_hint.visible = true

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_music_on = bool(cfg.get_value("audio", "music_on", true))
		_api_key = str(cfg.get_value("api", "key", ""))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", _music_on)
	cfg.set_value("api", "key", _api_key)
	cfg.save(CFG_PATH)
