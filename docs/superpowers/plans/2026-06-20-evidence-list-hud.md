# 证据列表 HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做一个常驻 HUD「证据」按钮:获得证据时弹 toast「已将【XX】添加到证据列表」,点开能看已获得证据的标题并读详情(proof)。

**Architecture:** 新增 autoload `Evidence`(`scenes/evidence_log.tscn`+`.gd`,CanvasLayer,仿道具栏 `Inv`)。列表内容即时从 `Game.state.has_key(card.key)` 派生,不新增数据模型。获得点发完 key 后调 `Evidence.note(k)` 弹 toast+红点,去重靠 `game_state.mark_evidence_seen`(随新游戏重置)。与审讯室"出示证据"toggle 开关解耦,一行不改。

**Tech Stack:** Godot 4 (GDScript)、headless `run_tests.gd` 确定性单测。

## Global Constraints

- **不动审讯室出示开关**:`interrogation.tscn` 的 4 个 toggle Card 按钮及其逻辑保持现状,一行不改。
- **不新增证据数据模型**:证据"是否获得"完全由现有 `Game.state.has_key(card.key)` 决定;列表读 `EVIDENCE_CARDS` 的 label/proof。
- **项目铁律(CLAUDE.md)**:摆着的控件(按钮/标签/面板/红点/toast)进 `.tscn` 当真实可拖节点;脚本只管逻辑。改/建 `.tscn` 后提醒用户在编辑器 **Reload Saved Scene**。
- **toast 去重**:同一证据整局只弹一次;非证据 key(home_address 等)忽略;去重状态随新游戏(新 `GameState`)自动清零。
- **EVIDENCE_CARDS 固定 4 条**(content.gd 现有,顺序:photo/death/farewell/molog),Entry 用 4 个固定节点。
- **测试命令**:
  `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
  全套单测:`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`(退出码 0=全过,末行 `结果: N 通过, M 失败`)
  结构测试:`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_evidence_log.gd`
  场景冒烟:`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/<场景>.tscn --quit-after 4`
  (headless 的 "ObjectDB leaked"/"resources still in use" 是无害告警,可忽略。)

---

### Task 1: 数据层 — content helper + game_state 去重

**Files:**
- Modify: `Game/client/game/content.gd`(EVIDENCE_CARDS 之后加静态 helper)
- Modify: `Game/client/game/game_state.gd`(加 evidence_seen + mark_evidence_seen)
- Test: `Game/client/tests/run_tests.gd`

**Interfaces:**
- Produces: `Content.evidence_card_for_key(key: String) -> Dictionary`(命中返回该证据卡字典,否则空字典)
- Produces: `GameState.evidence_seen: Dictionary` + `GameState.mark_evidence_seen(card_id: String) -> bool`(首次 true,重复/空 false)

- [ ] **Step 1: 写失败断言**

在 `tests/run_tests.gd` 末尾(`quit(...)` 之前)追加:

```gdscript
	# --- 证据列表:key→证据卡查询 ---
	_check(Content.evidence_card_for_key("linxiulan").get("id", "") == "death", "key linxiulan→death 卡")
	_check(Content.evidence_card_for_key("farewell").get("id", "") == "farewell", "key farewell→farewell 卡")
	_check(Content.evidence_card_for_key("photo").get("id", "") == "photo", "key photo→photo 卡")
	_check(Content.evidence_card_for_key("molog").get("id", "") == "molog", "key molog→molog 卡")
	_check(Content.evidence_card_for_key("home_address").is_empty(), "非证据 key home_address→空字典")
	_check(Content.evidence_card_for_key("").is_empty(), "空 key→空字典")
	# --- 证据列表:toast 去重 ---
	var es := GameState.new()
	_check(es.evidence_seen.is_empty(), "新局 evidence_seen 为空")
	_check(es.mark_evidence_seen("death") == true, "首次标记 death→true")
	_check(es.mark_evidence_seen("death") == false, "重复标记 death→false(去重)")
	_check(es.mark_evidence_seen("") == false, "空 card_id→false")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL,`Invalid call ... 'evidence_card_for_key'` 或断言 FAIL

- [ ] **Step 3a: content.gd 加 helper**

在 `content.gd` 的 `EVIDENCE_CARDS` 常量定义**之后**追加:

```gdscript
# 按 key 找对应证据卡;不是证据 key(如 home_address)返回空字典。
static func evidence_card_for_key(key: String) -> Dictionary:
	for c in EVIDENCE_CARDS:
		if str(c["key"]) == key:
			return c
	return {}
```

- [ ] **Step 3b: game_state.gd 加去重状态**

在 `game_state.gd` 的 `var presented := {}` 那行**之后**加成员变量:

```gdscript
var evidence_seen := {}   # 已弹过"获得证据"toast 的卡 id，去重(随新游戏=新 GameState 自动重置)
```

并在 `present_evidence` 函数**之后**加方法:

```gdscript
# 首次见该证据 → true(该弹 toast)；已弹过或空 → false。
func mark_evidence_seen(card_id: String) -> bool:
	if card_id == "" or evidence_seen.has(card_id):
		return false
	evidence_seen[card_id] = true
	return true
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS,新增断言全 ok,0 失败

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/content.gd Game/client/game/game_state.gd Game/client/tests/run_tests.gd
git commit -m "feat(evidence): content.evidence_card_for_key + game_state 证据toast去重"
```

---

### Task 2: 证据 HUD 场景 + 脚本 + autoload 注册

**Files:**
- Create: `Game/client/scenes/evidence_log.tscn`
- Create: `Game/client/scenes/evidence_log.gd`
- Modify: `Game/client/project.godot`([autoload] 加 Evidence)
- Create: `Game/client/tests/test_evidence_log.gd`

**Interfaces:**
- Consumes: `Content.EVIDENCE_CARDS`、`Content.evidence_card_for_key`、`Game.state.has_key`、`Game.state.mark_evidence_seen`(Task 1)
- Produces: autoload `Evidence`,方法 `Evidence.note(key: String)` / `Evidence.refresh()`;场景节点 `ToggleBtn`/`ToggleBtn/Dot`/`Panel`/`Panel/List/Entry0..3`/`Panel/Empty`/`Panel/Detail`/`Toast`

- [ ] **Step 1: 写结构测试(先失败)**

创建 `Game/client/tests/test_evidence_log.gd`:

```gdscript
extends SceneTree

var _pass := 0
var _fail := 0

func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("  ok  ", name)
	else:
		_fail += 1
		printerr("  FAIL ", name)

func _initialize() -> void:
	var scene := load("res://scenes/evidence_log.tscn") as PackedScene
	_check(scene != null, "evidence_log.tscn 可加载")
	if scene:
		var root := scene.instantiate()
		_check(root.has_node("ToggleBtn"), "有证据按钮 ToggleBtn")
		_check(root.has_node("ToggleBtn/Dot"), "证据按钮有红点 Dot")
		_check(root.has_node("Panel"), "有列表面板 Panel")
		_check(not root.get_node("Panel").visible, "Panel 默认隐藏")
		_check(root.has_node("Panel/List/Entry0"), "有证据条目 Entry0")
		_check(root.has_node("Panel/List/Entry1"), "有证据条目 Entry1")
		_check(root.has_node("Panel/List/Entry2"), "有证据条目 Entry2")
		_check(root.has_node("Panel/List/Entry3"), "有证据条目 Entry3")
		_check(root.has_node("Panel/Empty"), "有空状态标签 Empty")
		_check(root.has_node("Panel/Detail"), "有详情标签 Detail")
		_check(root.has_node("Toast"), "有 toast 标签")
		root.free()
	print("\n证据HUD测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_evidence_log.gd`
Expected: FAIL,`evidence_log.tscn 可加载` FAIL(文件不存在)

- [ ] **Step 3a: 建 evidence_log.gd**

创建 `Game/client/scenes/evidence_log.gd`:

```gdscript
# 证据列表(autoload 全局 HUD = Evidence)。右上角"📁 证据"按钮(道具栏左侧)，点开看已获得证据，
# 点条目读 proof 详情。获得证据的地方调 Evidence.note(key) 弹 toast+红点(去重)。
# 静态结构在 evidence_log.tscn(可拖)。序幕/结局用 Evidence.visible=false 隐藏整条。
extends CanvasLayer

const Content = preload("res://game/content.gd")

@onready var toggle_btn: Button = $ToggleBtn
@onready var dot: ColorRect = $ToggleBtn/Dot
@onready var panel: ColorRect = $Panel
@onready var entries: Array = [
	$Panel/List/Entry0, $Panel/List/Entry1, $Panel/List/Entry2, $Panel/List/Entry3
]
@onready var empty: Label = $Panel/Empty
@onready var detail: Label = $Panel/Detail
@onready var toast: Label = $Toast

var _toast_tween: Tween

func _ready() -> void:
	toggle_btn.pressed.connect(_toggle)
	for i in entries.size():
		(entries[i] as Button).pressed.connect(_on_entry.bind(i))
	panel.visible = false
	detail.visible = false
	dot.visible = false
	toast.visible = false
	refresh()

# 获得证据时调用(发完 key 后)：非证据 key 忽略；去重；弹 toast + 点红点。
func note(key: String) -> void:
	var card := Content.evidence_card_for_key(key)
	if card.is_empty():
		return
	if not Game.state.mark_evidence_seen(str(card["id"])):
		return
	_show_toast("已将【%s】添加到证据列表" % str(card["label"]))
	dot.visible = true
	refresh()

# 重建列表:每张卡按 has_key 显隐;无证据显示 Empty。
func refresh() -> void:
	var any := false
	for i in entries.size():
		var c: Dictionary = Content.EVIDENCE_CARDS[i]
		var held: bool = Game.state.has_key(str(c["key"]))
		(entries[i] as Button).visible = held
		(entries[i] as Button).text = str(c["label"])
		any = any or held
	empty.visible = not any

func _toggle() -> void:
	Sfx.play_click()
	panel.visible = not panel.visible
	if panel.visible:
		dot.visible = false   # 看了就清红点
		detail.visible = false
		refresh()

func _on_entry(i: int) -> void:
	Sfx.play_click()
	detail.text = str(Content.EVIDENCE_CARDS[i]["proof"])
	detail.visible = true

# 右上角淡入(0.3)停留(2.4)淡出(0.6) toast，仿 phone.gd。
func _show_toast(msg: String) -> void:
	toast.text = msg
	toast.visible = true
	toast.modulate.a = 0.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)
```

- [ ] **Step 3b: 建 evidence_log.tscn**

创建 `Game/client/scenes/evidence_log.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/evidence_log.gd" id="1_ev"]

[node name="Evidence" type="CanvasLayer"]
layer = 4
script = ExtResource("1_ev")

[node name="ToggleBtn" type="Button" parent="."]
offset_left = 988.0
offset_top = 12.0
offset_right = 1120.0
offset_bottom = 52.0
theme_override_font_sizes/font_size = 18
text = "📁 证据"

[node name="Dot" type="ColorRect" parent="ToggleBtn"]
visible = false
offset_left = 118.0
offset_top = -4.0
offset_right = 130.0
offset_bottom = 8.0
color = Color(0.9, 0.2, 0.2, 1)

[node name="Panel" type="ColorRect" parent="."]
visible = false
offset_left = 900.0
offset_top = 58.0
offset_right = 1268.0
offset_bottom = 430.0
color = Color(0, 0, 0, 0.6)

[node name="Title" type="Label" parent="Panel"]
offset_left = 16.0
offset_top = 10.0
offset_right = 320.0
offset_bottom = 42.0
theme_override_colors/font_color = Color(0.95, 0.9, 0.6, 1)
theme_override_font_sizes/font_size = 20
text = "证据"

[node name="List" type="VBoxContainer" parent="Panel"]
offset_left = 14.0
offset_top = 48.0
offset_right = 354.0
offset_bottom = 230.0
theme_override_constants/separation = 8

[node name="Entry0" type="Button" parent="Panel/List"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 16
text = "·"

[node name="Entry1" type="Button" parent="Panel/List"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 16
text = "·"

[node name="Entry2" type="Button" parent="Panel/List"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 16
text = "·"

[node name="Entry3" type="Button" parent="Panel/List"]
custom_minimum_size = Vector2(340, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 16
text = "·"

[node name="Empty" type="Label" parent="Panel"]
offset_left = 16.0
offset_top = 56.0
offset_right = 352.0
offset_bottom = 96.0
theme_override_colors/font_color = Color(0.8, 0.85, 0.8, 1)
theme_override_font_sizes/font_size = 16
text = "还没有收集到证据。"

[node name="Detail" type="Label" parent="Panel"]
visible = false
offset_left = 16.0
offset_top = 238.0
offset_right = 352.0
offset_bottom = 360.0
theme_override_colors/font_color = Color(0.92, 0.95, 0.9, 1)
theme_override_font_sizes/font_size = 15
autowrap_mode = 3

[node name="Toast" type="Label" parent="."]
visible = false
offset_left = 440.0
offset_top = 72.0
offset_right = 840.0
offset_bottom = 112.0
theme_override_colors/font_color = Color(0.95, 0.9, 0.6, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 0.9)
theme_override_constants/outline_size = 5
theme_override_font_sizes/font_size = 20
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 3c: project.godot 注册 autoload**

在 `Game/client/project.godot` 的 `[autoload]` 段,`Inv="*res://scenes/inventory.tscn"` **那一行之后**加:

```
Evidence="*res://scenes/evidence_log.tscn"
```

- [ ] **Step 4: 跑结构测试 + 全套测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_evidence_log.gd`
Expected: PASS,12 条结构断言全 ok
Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS,0 失败(加 autoload 不影响既有单测)

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/scenes/evidence_log.tscn Game/client/scenes/evidence_log.gd Game/client/project.godot Game/client/tests/test_evidence_log.gd
git commit -m "feat(evidence): 证据列表HUD场景+脚本+autoload注册(note/refresh/toggle/toast)"
```

提交后**提醒用户**:新增了 autoload,编辑器需 **重启/Reload** 才能看到证据 HUD。

---

### Task 3: 接线 — 获得点 note + 可见性同步

**Files:**
- Modify: `Game/client/scenes/terminal.gd`(`_grant_and_hint`、`_finish_log`)
- Modify: `Game/client/scenes/oldman_home.gd`(`_examine`)
- Modify: `Game/client/scenes/opening.gd:24` 附近
- Modify: `Game/client/scenes/world.gd:29` 与 `:109` 附近
- Modify: `Game/client/scenes/interrogation.gd:362` 附近

**Interfaces:**
- Consumes: `Evidence.note(key)`、`Evidence.visible`(Task 2)

> 本任务是把 HUD 接进游戏:获得证据处弹 toast、序幕/结局处隐藏。改动分散在 5 个文件、都是 1-2 行插入。无新单测(逻辑已在 Task 1/2 覆盖),靠全套单测无回归 + 关键场景冒烟加载无报错验证。

- [ ] **Step 1: terminal.gd 两处接 Evidence.note**

在 `scenes/terminal.gd` 的 `_grant_and_hint(id)` 里,`Game.state.add_key(k)` 那行**之后**加 `Evidence.note(k)`:

```gdscript
	var k := str(f.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)
		Evidence.note(k)
```

在 `_finish_log()` 里,`Game.state.add_key("molog")` 那行**之后**加:

```gdscript
	Game.state.add_key("molog")   # 第二层真相钥匙
	Evidence.note("molog")
```

- [ ] **Step 2: oldman_home.gd 接 Evidence.note**

在 `scenes/oldman_home.gd` 的 `_examine(id)` 里,`Game.state.add_key(k)` 那行**之后**加:

```gdscript
	var k := str(e.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)
		Evidence.note(k)
```

- [ ] **Step 3: 可见性同步(序幕/主世界/结局)**

`scenes/opening.gd` 第 24 行 `Inv.visible = false` **之后**加:
```gdscript
	Evidence.visible = false
```

`scenes/world.gd` 第 29 行 `Inv.visible = not intro_from_opening` **之后**加:
```gdscript
	Evidence.visible = not intro_from_opening
```
`scenes/world.gd` 第 109 行 `Inv.visible = true` **之后**加:
```gdscript
	Evidence.visible = true
```

`scenes/interrogation.gd` 第 362 行 `Inv.visible = false` **之后**加:
```gdscript
	Evidence.visible = false
```

- [ ] **Step 4: 全套单测 + 关键场景冒烟无报错**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS,0 失败
Run(逐个,都要无 `SCRIPT ERROR`/`Node not found`,干净退出):
```
"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/terminal.tscn --quit-after 4
"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/oldman_home.tscn --quit-after 4
"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/world.tscn --quit-after 4
"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/interrogation.tscn --quit-after 4
"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/opening.tscn --quit-after 4
```
Expected: 每个都干净退出(审讯室可能有无害 "resources still in use" 告警,可忽略)

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/scenes/terminal.gd Game/client/scenes/oldman_home.gd Game/client/scenes/opening.gd Game/client/scenes/world.gd Game/client/scenes/interrogation.gd
git commit -m "feat(evidence): 接线-3个获得点弹toast + 序幕/主世界/结局同步证据HUD可见性"
```

- [ ] **Step 6: 更新项目记忆并提交**

更新 `PROJECT_PROGRESS.md`(最近进展加"证据列表 HUD 落地")、`PROJECT_TODO.md`(证据列表标完成)。

```bash
cd /Users/xulei/.dev/Distortion
git add PROJECT_PROGRESS.md PROJECT_TODO.md
git commit -m "docs(memory): 记录证据列表HUD落地"
```

---

## Self-Review

**Spec coverage(逐节对照):**
- 常驻 HUD「证据」按钮 + 红点 + 列表 + 详情 → Task 2(tscn+gd)✓
- 列表内容由 has_key 派生、不新增数据模型 → Task 2 `refresh()`、Task 1 helper ✓
- toast「已将【XX】添加到证据列表」+ 去重 → Task 2 `note()`/`_show_toast`、Task 1 `mark_evidence_seen` ✓
- 3 个获得点接线(终端死亡/安葬、家里合照、终端日志)→ Task 3 Step 1-2 ✓
- 与审讯室出示开关解耦(不改)→ 全程未碰 interrogation 的 Card 节点 ✓
- 可见性同步(序幕/世界/结局)→ Task 3 Step 3 ✓
- autoload 注册 → Task 2 Step 3c ✓
- 单测(key→卡/去重/场景节点)→ Task 1 + Task 2 结构测试 ✓
- 非证据 key 忽略、空列表、重复获得不重弹 → Task 1 断言 + Task 2 `note`/`refresh` ✓

**Placeholder 扫描:** 无 TBD/TODO;所有步骤含完整代码与命令。

**类型一致性:** `evidence_card_for_key`(返回 Dictionary)、`mark_evidence_seen`(返回 bool)、`note`/`refresh`/`_on_entry`/`_show_toast`、节点名 `ToggleBtn/Dot/Panel/List/Entry0..3/Empty/Detail/Toast` 在 tscn(Task2)、gd 引用(Task2)、结构测试(Task2)三处一致;autoload 名 `Evidence` 在注册(Task2)与接线(Task3)一致。

**已知衔接点:** Task 2 注册 autoload 后,证据 HUD 默认 `visible=true` 会在序幕/结局短暂露出,直到 Task 3 Step 3 同步隐藏——非报错,仅视觉,两任务连续执行即可。Task 3 依赖 Task 2 的 `Evidence` autoload 存在。
