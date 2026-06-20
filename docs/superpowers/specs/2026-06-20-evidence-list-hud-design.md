# 证据列表 HUD 设计稿

- 日期：2026-06-20
- 分支：`feat/finale-emergent-ending`(承接终端查询机之后)
- 范围级别：P0(新 autoload HUD + 跨多场景接线)

## 一、目标与背景

### 现状缺口
玩家在终端查到死亡/安葬记录、在老人家看合照、在终端翻完莫忘日志时，会获得"证据"(对应 `EVIDENCE_CARDS` 的 photo/linxiulan/farewell/molog 四把 key)，但：
1. **获得时没有任何"得到证据"的反馈**——只有引导回审讯室的莫忘提醒。
2. **玩家读不到证据详情**——审讯室那 4 个 toggle 开关只显示标题("合照""死亡证明")，`proof` 全文只喂模型、玩家看不到。
3. **没有能翻看证据的列表**。

### 本轮做什么
做一个**常驻 HUD 证据列表**：获得证据时弹 toast「已将【XX】添加到证据列表」，玩家可随时点开「证据」按钮查看已获得证据的标题与详情(`proof` 全文)；审讯室对峙时同样能打开查看。

### 已定决策(brainstorming 确认)
- **查看入口**：常驻 HUD「证据」按钮(仿道具栏 `Inv`，全局常驻，审讯室里自然也能开)。
- **与审讯室"出示证据"4 个 toggle 开关的关系**：**分开，互不影响**。证据列表=只读查看/读详情；出示开关保持现状(对峙摆牌给老头)，一行不改。
- **toast 时机**：所有证据获得点都弹。

## 二、架构

新增一个 autoload `Evidence`(场景 `scenes/evidence_log.tscn` + `scenes/evidence_log.gd`，CanvasLayer)，与现有道具栏 `Inv` 平行：

```
Evidence (CanvasLayer, layer=4)  ← autoload
├─ ToggleBtn (Button "📁 证据")      右上角，道具栏按钮左侧；点击开/收列表面板
│   └─ Dot (ColorRect/Label 红点)    有新证据未看时可见
├─ Panel (ColorRect, 默认 hidden)    证据列表面板
│   ├─ Title (Label "证据")
│   ├─ List (VBoxContainer)
│   │   ├─ Entry0 (Button)           ← 4 个固定按钮，对应 EVIDENCE_CARDS 顺序
│   │   ├─ Entry1 (Button)             只在 has_key(card.key) 时 visible
│   │   ├─ Entry2 (Button)
│   │   └─ Entry3 (Button)
│   ├─ Empty (Label "还没有收集到证据。")  无证据时显示
│   └─ Detail (Label, autowrap)      点某条 → 显示该条 proof 全文
└─ (无独立 Close：再点 ToggleBtn 收起)
```

> 4 个 Entry 用**固定节点**(EVIDENCE_CARDS 最多 4 条)，符合项目铁律"摆着的进 .tscn 可拖"。按钮位置/大小用户可在编辑器拖。

## 三、数据：复用现有 key 状态，不新增模型

证据"是否已获得"完全由现有 `Game.state.has_key(card.key)` 决定，列表内容即时从中派生。`EVIDENCE_CARDS`(content.gd)四条：

| id | label | key | proof(玩家可读) | 获得点 |
|---|---|---|---|---|
| photo | 合照 | photo | 周明远与林秀兰的合照——她确实是他妻子。 | oldman_home 查合照 |
| death | 死亡证明 | linxiulan | 林秀兰的死亡证明：三年前因慢性肺病去世…… | 终端查"妻子" |
| farewell | 安葬记录 | farewell | 她的骨灰安放记录，经办人是周明远本人…… | 终端查"安葬" |
| molog | 莫忘日志 | molog | 莫忘的历史日志：是它一遍遍说"她只是走丢了…… | 终端翻完莫忘日志 |

`home_address` 等非证据 key 不在 `EVIDENCE_CARDS` 里，自然不显示。

## 四、key → 证据卡查询 + toast 去重(可单测)

### content.gd 新增静态 helper
```gdscript
# 按 key 找对应证据卡；不是证据 key(如 home_address)返回空字典。
static func evidence_card_for_key(key: String) -> Dictionary:
	for c in EVIDENCE_CARDS:
		if str(c["key"]) == key:
			return c
	return {}
```

### game_state.gd 新增去重状态
```gdscript
var evidence_seen := {}   # 已弹过"获得证据"toast 的卡 id，去重(随新游戏=新 GameState 自动重置)

# 首次见 → true(该弹 toast)；已弹过/空 → false。
func mark_evidence_seen(card_id: String) -> bool:
	if card_id == "" or evidence_seen.has(card_id):
		return false
	evidence_seen[card_id] = true
	return true
```
> `Game.state` 在新游戏时重建，`evidence_seen` 随之清零——重复查同一档案不会重复弹，新开一局又能重新弹。

## 五、evidence_log.gd 行为

```gdscript
extends CanvasLayer
const Content = preload("res://game/content.gd")
# @onready 引用 ToggleBtn/Dot/Panel/Entry0..3/Empty/Detail

func _ready():
	toggle_btn.pressed.connect(_toggle)
	for i in 4: entries[i].pressed.connect(_on_entry.bind(i))
	panel.visible = false
	detail.visible = false
	refresh()

# 获得证据时调用(发完 key 后)：非证据 key 忽略；去重；弹 toast + 点红点。
func note(key: String):
	var card = Content.evidence_card_for_key(key)
	if card.is_empty(): return
	if not Game.state.mark_evidence_seen(str(card["id"])): return
	_show_toast("已将【%s】添加到证据列表" % str(card["label"]))
	_set_dot(true)

# 重建列表：每张卡按 has_key 显隐；无证据显示 Empty。
func refresh():
	var any := false
	for i in 4:
		var c = Content.EVIDENCE_CARDS[i]
		var held: bool = Game.state.has_key(str(c["key"]))
		entries[i].visible = held
		entries[i].text = str(c["label"])
		any = any or held
	empty.visible = not any

func _toggle():
	Sfx.play_click()
	panel.visible = not panel.visible
	if panel.visible:
		_set_dot(false)   # 看了就清红点
		detail.visible = false
		refresh()

func _on_entry(i):
	Sfx.play_click()
	detail.text = str(Content.EVIDENCE_CARDS[i]["proof"])
	detail.visible = true

func _show_toast(msg): # 复用 phone.gd 那套淡入(0.3)停留(2.6)淡出(0.6)，节点可在 tscn 里
func _set_dot(on): dot.visible = on
```

## 六、接线点(精确)

### 证据获得点 → 调 `Evidence.note(k)`(发完 key 之后)
1. `scenes/terminal.gd` `_grant_and_hint(id)`：`Game.state.add_key(k)` 后加 `Evidence.note(k)`(linxiulan/farewell 命中；home_address 被 note 忽略)。
2. `scenes/oldman_home.gd` `_examine(id)`：`Game.state.add_key(k)` 后加 `Evidence.note(k)`(photo 命中)。
3. `scenes/terminal.gd` `_finish_log()`：`Game.state.add_key("molog")` 后加 `Evidence.note("molog")`。

### 可见性同步(凡 `Inv.visible` 处同步 `Evidence.visible`)
4. `scenes/opening.gd:24`：`Evidence.visible = false`(序幕隐藏)。
5. `scenes/world.gd:29`：`Evidence.visible = not intro_from_opening`；`world.gd:109`：`Evidence.visible = true`。
6. `scenes/interrogation.gd:362`：`Evidence.visible = false`(结局幻灯片隐藏)。

### project.godot
7. `[autoload]` 加 `Evidence="*res://scenes/evidence_log.tscn"`(放在 `Inv` 之后)。

## 七、错误处理与边界
- `note()` 收到非证据 key(home_address 等)→ `evidence_card_for_key` 返回空 → 直接 return，不弹。
- 重复获得同一证据(重复查同一档案)→ `mark_evidence_seen` 返回 false → 不重复弹。
- 列表为空 → 显示 Empty 提示，不显示任何 Entry。
- 点开列表即清红点(已读)。
- 证据 HUD 不锁玩家移动(仅一个面板，仿 Inv，不仿 phone 的锁定)。

## 八、验证(验收门槛)
### headless 单测(`tests/run_tests.gd`，必须全绿)
- `Content.evidence_card_for_key("linxiulan")` 返回 death 卡(label=死亡证明)；`("farewell")`→farewell；`("photo")`→photo；`("molog")`→molog；`("home_address")`→空字典；`("")`→空字典。
- `game_state.mark_evidence_seen("death")` 首次 true、第二次 false；空串 false；新 `GameState.new()` 的 `evidence_seen` 为空。
- `evidence_log.tscn` 能加载，含节点 `ToggleBtn`/`ToggleBtn/Dot`/`Panel`/`Panel/List/Entry0..3`/`Panel/Empty`/`Panel/Detail`，默认 `Panel` 隐藏。
- 新建 `tests/test_evidence_log.gd` 结构测试。

### 用户 F5 实机(最终)
- 终端查死亡/安葬、家里看合照、终端翻完日志 → 各弹一次「已将【XX】添加到证据列表」+ 红点。
- 点右上角「证据」→ 列表显示已获得的，点条目读 proof 详情；没证据时显示空提示。
- 审讯室对峙时能打开证据列表查看。
- 序幕/结局幻灯片期间证据按钮不露出。

## 九、不在本轮范围(YAGNI)
- 不动审讯室 4 个 toggle 出示开关(摆牌机制保持现状)。
- 证据不加配图(proof 文字即内容)。
- 不做证据"已出示/未出示"在列表里的状态标记(列表只读，与出示解耦)。

## 十、影响文件清单
| 文件 | 改动 |
|---|---|
| `scenes/evidence_log.tscn`(新建) | 证据 HUD 场景:ToggleBtn+Dot+Panel(Title/List/Entry0..3/Empty/Detail) |
| `scenes/evidence_log.gd`(新建) | note/refresh/toggle/on_entry/toast/dot 逻辑 |
| `project.godot` | autoload 加 `Evidence` |
| `game/content.gd` | 加 `evidence_card_for_key` 静态 helper |
| `game/game_state.gd` | 加 `evidence_seen` + `mark_evidence_seen` |
| `scenes/terminal.gd` | `_grant_and_hint`/`_finish_log` 接 `Evidence.note` |
| `scenes/oldman_home.gd` | `_examine` 接 `Evidence.note` |
| `scenes/opening.gd`/`world.gd`/`interrogation.gd` | 同步 `Evidence.visible` |
| `tests/run_tests.gd` + `tests/test_evidence_log.gd` | 单测 + 结构测试 |
