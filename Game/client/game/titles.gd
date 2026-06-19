# 成就称号收藏：去重持久化到 user://achievements.cfg。autoload 名 Titles。
extends Node

const CFG_PATH := "user://achievements.cfg"
var _titles: Array = []   # 按获得顺序，已去重

func _ready() -> void:
	_load_from(CFG_PATH)

func _load_from(path: String) -> void:
	_titles = []
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var arr = cfg.get_value("titles", "list", [])
		if arr is Array:
			for t in arr:
				var s := str(t).strip_edges()
				if s != "" and not (s in _titles):
					_titles.append(s)

func _save_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("titles", "list", _titles)
	cfg.save(path)

# 纯内存去重注册，返回是否新增（落盘见 add_title）。
func _register(t: String) -> bool:
	var s := t.strip_edges()
	if s == "" or s in _titles:
		return false
	_titles.append(s)
	return true

func add_title(t: String) -> bool:
	var added := _register(t)
	if added:
		_save_to(CFG_PATH)
	return added

func all_titles() -> Array:
	return _titles.duplicate()

func count() -> int:
	return _titles.size()

func has(t: String) -> bool:
	return t.strip_edges() in _titles
