# 主菜单 + 成就称号系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** 加启动主菜单 + 每次大结局后 AI 评一个 ≤10 字称号、去重持久化为成就、可在成就面板查看；结局画面显示称号并提供返回主菜单/查看成就。

**Architecture:** 新 autoload `Titles`(存 `user://achievements.cfg`) + `llm.gd` 第三个 LLM 调用(称号评定) + 主菜单/成就两个新场景 + 结局画面集成。无中途存档。

**Tech Stack:** Godot 4 GDScript；测试 `tests/run_tests.gd`(SceneTree+`_check`) + 独立 `test_*.gd`。

## Global Constraints
- 复用现有模式：持久化用 `ConfigFile`（同 `settings.gd` 的 `user://settings.cfg`）。
- 静态结构进 `.tscn`(可拖)，脚本只管逻辑；列表用单个 Label 填文本，不脚本造控件。
- **称号 ≤10 字**，代码兜死；异常/空 → 兜底「过客」。
- 称号去重：同名只计一次。
- Godot：`/Applications/Godot.app/Contents/MacOS/Godot`（下称 `$GODOT`）；命令在 `Game/client/` 下跑。
- 全套单测：`$GODOT --headless --path . -s res://tests/run_tests.gd`（exit 0）。
- 场景加载：`$GODOT --headless --path . res://scenes/<场景>.tscn --quit-after 6`。
- 改 `.tscn`/`project.godot` 后提醒用户 Reload / 重启编辑器。
- 每任务末尾 commit，中文单意图。

---

### Task 1: Titles autoload（称号持久化）

**Files:** Create `game/titles.gd`; Modify `project.godot`(注册 autoload); Modify `tests/run_tests.gd`.

**Interfaces (Produces):** autoload `Titles`：`add_title(t)->bool`(新增=true,去重)、`all_titles()->Array`、`count()->int`、`has(t)->bool`；内部 `_register(t)->bool`(纯内存去重)、`_save_to(path)`、`_load_from(path)`。

- [ ] **Step 1: 加断言到 run_tests.gd**
```gdscript
# --- Titles 称号收藏 ---
var Tt = preload("res://game/titles.gd")
var tt = Tt.new()
_check(tt._register("真相揭穿者"), "首次注册称号=新")
_check(not tt._register("真相揭穿者"), "重复注册同名=非新(去重)")
_check(not tt._register("  真相揭穿者  "), "去空格后仍判重复")
_check(not tt._register(""), "空称号不注册")
_check(tt.count() == 1, "去重后只 1 个")
tt._register("下一个莫忘")
_check(tt.all_titles() == ["真相揭穿者", "下一个莫忘"], "按获得顺序返回")
# 存档 round-trip(临时路径,不污染真实存档)
var tmp := "user://_test_ach.cfg"
tt._save_to(tmp)
var tt2 = Tt.new()
tt2._load_from(tmp)
_check(tt2.all_titles() == ["真相揭穿者", "下一个莫忘"], "存档读档 round-trip 一致")
_check(not tt2._register("真相揭穿者"), "读档后仍去重")
DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
```

- [ ] **Step 2: 跑测试 RED** — `$GODOT --headless --path . -s res://tests/run_tests.gd` → FAIL(脚本不存在)。

- [ ] **Step 3: 写 game/titles.gd**
```gdscript
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
```

- [ ] **Step 4: 注册 autoload** —— `project.godot` 的 `[autoload]` 段加一行（放在 Game 之后即可）：
```
Titles="*res://game/titles.gd"
```

- [ ] **Step 5: 跑测试 GREEN** — 同上命令 → PASS。

- [ ] **Step 6: Commit** — `git add game/titles.gd project.godot tests/run_tests.gd && git commit -m "feat(titles): 成就称号去重持久化 autoload(user://achievements.cfg)"`

---

### Task 2: llm.gd 称号评定调用

**Files:** Modify `game/llm.gd`; Modify `tests/run_tests.gd`.

**Interfaces (Produces):** `LLM.TITLE_PROMPT`；`LLM.build_title_messages(history, ending_kind)->Array`；`LLM.title_request_body(history, ending_kind)->String`；`LLM.parse_title(content)->String`(≤10字,剥引号标点,空→"")。

- [ ] **Step 1: 加断言**
```gdscript
# --- 称号评定 ---
_check(LLM.parse_title("「真相揭穿者」") == "真相揭穿者", "剥书名/引号包裹")
_check(LLM.parse_title("称号：固执的等待者。") == "称号：固执的等待" or LLM.parse_title("固执的等待者。").length() <= 10, "截断到≤10字")
_check(LLM.parse_title("下一个莫忘\n（解释...）") == "下一个莫忘", "只取第一行")
_check(LLM.parse_title("   ") == "", "空白→空串")
_check(LLM.parse_title("一二三四五六七八九十十一十二") == "一二三四五六七八九十", "超10字截断到10")
var tm := LLM.build_title_messages([{"role":"user","content":"她去世了"}], "truth")
_check(tm.size() == 2 and tm[0]["role"] == "system" and "truth" in tm[1]["content"], "称号messages带提示+结局类型")
```

- [ ] **Step 2: RED** → FAIL。

- [ ] **Step 3: 实现 llm.gd（加在 director 相关函数附近）**
```gdscript
const TITLE_PROMPT := """你是这个赛博朋克叙事侦探游戏的"称号评定官"。
玩家是审讯老人周明远的侦探。根据玩家这一局与老人的【全部对话】和【结局类型】，
给玩家评定一个称号：凝练、有态度、有点冷峻或反讽，像游戏成就里的称号。
【硬性要求】不超过 10 个字；只输出称号本身，不要任何解释、前后缀、标点包裹或引号。"""

static func build_title_messages(history: Array, ending_kind: String) -> Array:
	var transcript := ""
	for m in history:
		var who := "玩家" if str(m.get("role")) == "user" else "周明远"
		transcript += who + "：" + str(m.get("content")) + "\n"
	var ctx := "【结局类型】%s\n【这一局的全部对话】\n%s\n给玩家起一个不超过10个字的称号，只输出称号本身。" % [ending_kind, transcript]
	return [{"role": "system", "content": TITLE_PROMPT}, {"role": "user", "content": ctx}]

static func title_request_body(history: Array, ending_kind: String) -> String:
	return JSON.stringify({
		"model": MODEL,
		"messages": build_title_messages(history, ending_kind),
		"temperature": 0.7,
	})

# 解析称号：取首行、剥首尾引号/标点、截断到 ≤10 字；异常返回 ""(调用方兜底)。
static func parse_title(content: String) -> String:
	var t := str(content).strip_edges()
	var nl := t.find("\n")
	if nl >= 0:
		t = t.substr(0, nl).strip_edges()
	var wrap := ["\"", "'", "「", "」", "『", "』", "《", "》", "【", "】", "“", "”", "‘", "’", "。", ".", "：", ":", "、", "，", ","]
	var changed := true
	while changed:
		changed = false
		for c in wrap:
			if t.begins_with(c):
				t = t.substr(c.length()); changed = true
			if t.ends_with(c):
				t = t.substr(0, t.length() - c.length()); changed = true
		t = t.strip_edges()
	if t.length() > 10:
		t = t.substr(0, 10)
	return t
```

- [ ] **Step 4: GREEN** → PASS。（注：第1条断言里"称号："前缀因 `：` 在 wrap 列表只剥首尾，行内"称号："不会被剥——调整断言或接受 `parse_title("固执的等待者。")` 这种纯称号用例；实现时以"剥首尾包裹 + 截断"为准，断言按实际行为写实。）

- [ ] **Step 5: Commit** — `git add game/llm.gd tests/run_tests.gd && git commit -m "feat(llm): 加称号评定 TITLE_PROMPT/build_title_messages/parse_title(≤10字兜死)"`

---

### Task 3: 主菜单场景 + 设为启动场景

**Files:** Create `scenes/main_menu.tscn` + `scenes/main_menu.gd`; Modify `project.godot`(`run/main_scene`); Create `tests/test_main_menu.gd`.

**Interfaces (Produces):** 节点 `$Title`、`$Buttons/StartBtn`、`$Buttons/AchieveBtn`、`$Buttons/QuitBtn`。

- [ ] **Step 1: 结构测试 `tests/test_main_menu.gd`**（仿 test_interrogation_struct.gd）
```gdscript
extends SceneTree
func _initialize() -> void:
	var root = load("res://scenes/main_menu.tscn").instantiate()
	var ok := true
	for p in ["Buttons/StartBtn", "Buttons/AchieveBtn", "Buttons/QuitBtn"]:
		if root.get_node_or_null(p) == null:
			push_error("缺节点 " + p); ok = false
	print("main_menu 结构 " + ("OK" if ok else "FAIL"))
	root.free(); quit(0 if ok else 1)
```

- [ ] **Step 2: RED** — `$GODOT --headless --path . -s res://tests/test_main_menu.gd` → FAIL。

- [ ] **Step 3: 建 main_menu.tscn**（Control 根，色块 ColorRect 背景 + `Title` Label「失真 Distortion」+ `Buttons` VBox 含 3 个 Button：StartBtn「开始游戏」/AchieveBtn「成就」/QuitBtn「退出」；Zpix 默认字体）。`main_menu.gd`：
```gdscript
extends Control
const OPENING := "res://scenes/opening.tscn"
const ACHIEVE := "res://scenes/achievements.tscn"
@onready var start_btn: Button = $Buttons/StartBtn
@onready var achieve_btn: Button = $Buttons/AchieveBtn
@onready var quit_btn: Button = $Buttons/QuitBtn
func _ready() -> void:
	Music.play_opening()
	start_btn.pressed.connect(func() -> void: Sfx.play_click(); get_tree().change_scene_to_file(OPENING))
	achieve_btn.pressed.connect(func() -> void: Sfx.play_click(); get_tree().change_scene_to_file(ACHIEVE))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	start_btn.grab_focus()
```
> `achievements.tscn` 由 Task 4 建；本任务 AchieveBtn 先连好，Task 4 完成后即可用。若 Task 4 未完成，无头加载 main_menu 不会因连接报错（只在点击时切场景）。

- [ ] **Step 4: 设启动场景** — `project.godot`：`run/main_scene="res://scenes/main_menu.tscn"`。

- [ ] **Step 5: GREEN + 场景加载** — 结构测试 PASS；`$GODOT --headless --path . res://scenes/main_menu.tscn --quit-after 3` 无脚本错误。

- [ ] **Step 6: Commit** — `git add scenes/main_menu.tscn scenes/main_menu.gd project.godot tests/test_main_menu.gd && git commit -m "feat(menu): 启动主菜单(开始游戏/成就/退出)并设为 run/main_scene"`

---

### Task 4: 成就面板场景

**Files:** Create `scenes/achievements.tscn` + `scenes/achievements.gd`; Create `tests/test_achievements.gd`.

**Interfaces (Consumes):** `Titles.all_titles()`/`count()`. **Produces 节点:** `$CountLabel`、`$Scroll/List`(Label)、`$BackBtn`。

- [ ] **Step 1: 结构测试 `tests/test_achievements.gd`**
```gdscript
extends SceneTree
func _initialize() -> void:
	var root = load("res://scenes/achievements.tscn").instantiate()
	var ok := true
	for p in ["CountLabel", "Scroll/List", "BackBtn"]:
		if root.get_node_or_null(p) == null:
			push_error("缺节点 " + p); ok = false
	print("achievements 结构 " + ("OK" if ok else "FAIL"))
	root.free(); quit(0 if ok else 1)
```

- [ ] **Step 2: RED** → FAIL。

- [ ] **Step 3: 建 achievements.tscn**（Control 根 + 背景 ColorRect + `CountLabel` Label + `Scroll`(ScrollContainer) 内 `List`(Label,autowrap) + `BackBtn` Button「返回」）。`achievements.gd`：
```gdscript
extends Control
const MENU := "res://scenes/main_menu.tscn"
@onready var count_label: Label = $CountLabel
@onready var list_label: Label = $Scroll/List
@onready var back_btn: Button = $BackBtn
func _ready() -> void:
	var titles := Titles.all_titles()
	count_label.text = "已获得 %d 个称号" % titles.size()
	list_label.text = "暂无称号，去玩一局吧。" if titles.is_empty() else "　".join(PackedStringArray(titles)).replace("　", "\n") if false else "\n".join(PackedStringArray(titles))
	back_btn.pressed.connect(func() -> void: Sfx.play_click(); get_tree().change_scene_to_file(MENU))
	back_btn.grab_focus()
```
> 简化 list 文本：`list_label.text = "暂无称号，去玩一局吧。" if titles.is_empty() else "\n".join(PackedStringArray(titles))`（实现时用这句，去掉上面的占位三元）。

- [ ] **Step 4: GREEN + 场景加载** — 结构测试 PASS；`$GODOT --headless --path . res://scenes/achievements.tscn --quit-after 3` 无脚本错误。

- [ ] **Step 5: Commit** — `git add scenes/achievements.tscn scenes/achievements.gd tests/test_achievements.gd && git commit -m "feat(menu): 成就面板(称号收藏列表+计数+返回)"`

---

### Task 5: 结局集成（显示称号 + 返回主菜单/查看成就）

**Files:** Modify `scenes/interrogation.tscn`(EndSlide 加 TitleLabel + 两按钮 + TitleHttp 节点); Modify `scenes/interrogation.gd`; Modify `tests/test_interrogation_struct.gd`.

**Interfaces (Consumes):** `LLM.title_request_body`/`LLM.parse_title`、`Titles.add_title`、`_pending_end`(已有,含 kind)。

- [ ] **Step 1: 扩 test_interrogation_struct.gd** — 加断言节点存在：`EndSlide/VBox/TitleLabel`、`EndSlide/VBox/EndButtons/BackToMenuBtn`、`EndSlide/VBox/EndButtons/ViewAchieveBtn`、`TitleHttp`。

- [ ] **Step 2: RED** — `$GODOT --headless --path . -s res://tests/test_interrogation_struct.gd` → FAIL。

- [ ] **Step 3: 改 interrogation.tscn** — `EndSlide/VBox` 下加 `TitleLabel`(Label,初始空)；加 `EndButtons`(HBox) 含 `BackToMenuBtn`「返回主菜单」+ `ViewAchieveBtn`「查看成就」；根下加 `TitleHttp`(HTTPRequest)。

- [ ] **Step 4: 改 interrogation.gd**
  - `@onready var title_label: Label = $EndSlide/VBox/TitleLabel`、`back_menu_btn`、`view_achieve_btn`、`title_http: HTTPRequest = $TitleHttp`。
  - `_ready` 连：`title_http.request_completed.connect(_on_title)`；`back_menu_btn.pressed.connect(func(): Sfx.play_click(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))`；`view_achieve_btn.pressed.connect(func(): Sfx.play_click(); get_tree().change_scene_to_file("res://scenes/achievements.tscn"))`。
  - `_trigger_ending_emergent(epilogue)` 末尾(已 `finished=true`)：发称号请求 —— `var kind := str(_pending_end.get("kind", ""))`；`title_label.text = ""`；`title_http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, LLM.title_request_body(state.history, kind))`。
  - 新增：
```gdscript
func _on_title(_result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var t := ""
	if code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		t = LLM.parse_title(LLM.extract_content(data))
	if t == "":
		t = "过客"
	var is_new := Titles.add_title(t)
	title_label.text = "你获得称号：%s%s" % [t, "（新！）" if is_new else ""]
```

- [ ] **Step 5: GREEN + 场景加载 + 全套** — 结构测试 OK；`interrogation.tscn` 加载干净；`run_tests.gd` 全过。

- [ ] **Step 6: Commit** — `git add scenes/interrogation.gd scenes/interrogation.tscn tests/test_interrogation_struct.gd && git commit -m "feat(finale): 结局发AI称号请求+显示称号(≤10字,兜底过客)+返回主菜单/查看成就"`

---

## Self-Review（spec 覆盖）
- 主菜单(开始/成就/退出 + run/main_scene)→ T3 ✅
- 称号持久化去重 → T1 ✅
- AI 称号 ≤10 字兜死 → T2 ✅
- 结局显示称号 + 入库 + 返回菜单/查看成就 → T5 ✅
- 成就面板列表+计数 → T4 ✅
- 真 key 称号抽查 = 实现后单独脚本验证(非单测) ✅
