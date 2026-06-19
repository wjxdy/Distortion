# 终局重构 + 失踪妻子剧情改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把剧情改成"妻子失踪·天天报案·AI 哄他她会回来·真相是她早已病逝"，并把终局结局系统重构为"老头/裁判双调用 + 证据手牌驱动 + AI 现写结局"。

**Architecture:** 全程复用现有场景，只改文案 / content 数据 / 提示词 / 结局电路代码；唯一新增结构 = 审讯室证据手牌（4 个静态 toggle 按钮）+ 第二个 HTTPRequest（裁判）。结局由独立"裁判"调用客观判定并现写正文，老头那次调用只负责演、不判结局。

**Tech Stack:** Godot 4 (GDScript)，客户端直连 Moonshot（`game/llm.gd`）；无头测试 runner `tests/run_tests.gd`（`SceneTree` + `_check`）。

## Global Constraints

- **复用现有场景**：不新建场景、不重排场景树；只改文案/数据/提示词/逻辑。唯一新增节点 = `interrogation.tscn` 内证据面板 + `DirectorHttp`。
- **铁律**：静态结构进 `.tscn`（可拖），脚本只管逻辑/动态。证据牌做成 4 个静态 toggle 按钮，不脚本动态 new 控件。
- **Godot 二进制**：`/Applications/Godot.app/Contents/MacOS/Godot`（下称 `$GODOT`）。
- **全部命令在 `Game/client/` 目录下运行。**
- **跑全套单测**：`$GODOT --headless --path . -s res://tests/run_tests.gd`（退出码 0=全过）。
- **场景加载校验**：`$GODOT --headless --path . res://scenes/<场景>.tscn --quit-after 6`（无报错即可）。
- **统一字幕不变**：`Content.ENDING == "记忆，是我们选择记住的版本。"`
- **黑暗结局留白暗示**，不直给血腥/自杀画面。
- **改 `.tscn` 后提醒用户在编辑器 Reload Saved Scene。**
- **真 key 调试脚本写 `/tmp`，用完即弃，不进仓库；仓库 `llm.gd` 的 `API_KEY` 永远留占位符。**
- 每个 Task 末尾 commit；commit message 用中文、单意图。

---

## 文件结构（改动总览）

| 文件 | 职责 | 改动 |
|---|---|---|
| `game/content.gd` | 剧情数据 | 全文案改新剧情；`no_accident`→`farewell`；新增 `EVIDENCE_CARDS`/`ENDING_FALLBACK`；`ENDING_SLIDES` 退役；`MOWANG_*`/`BOSS_TASK`/`MOWANG_HINTS`/`TERMINAL_FILES`/`EXPLORE_ACTIONS`/`HOME_EVIDENCE` 改写 |
| `game/triggers.gd` | 真相钩子 | 不改逻辑（关键词来自 Content.TRUTHS）|
| `game/game_state.gd` | 状态 | 新增 `presented`/`present_evidence`/`presented_proofs`；删 `investigation_summary`/`PROGRESS_FACTS`；`in_finale` 保留 |
| `game/llm.gd` | 提示词+解析 | 重写 `SYSTEM_PROMPT`/`FINALE_SYSTEM_PROMPT`（roleplay 不吐结局）；新增 `DIRECTOR_PROMPT`/`build_director_messages`/`parse_director`；`parse_reply` 删 end 逻辑；删 `VALID_END` |
| `scenes/interrogation.gd` | 审讯逻辑 | 证据面板（点亮/toggle/出示注入）；`_send` 注入 presented 旁白；`_finale_turns`；裁判请求编排；结局打字机完成后触发（修 bug）；删 leave；hint_fallback 改新剧情 |
| `scenes/interrogation.tscn` | 审讯场景 | 加证据面板（4 toggle 按钮）+ `DirectorHttp`；删 `LeaveBtn` |
| `scenes/terminal.gd` | 终端 | `FILE_HINTS` 文案/键名对齐新剧情 |
| `tests/run_tests.gd` | 单测 | 同步更新被改动影响的断言；新增 presented/cards/director 断言 |

---

## Phase A — 剧情文案改版（content + 受影响的单测）

### Task A1: content.gd 终端/档案文案 + `no_accident`→`farewell` + TRUTHS

**Files:**
- Modify: `game/content.gd`（`TRUTHS`/`TERMINAL_FILES`/`EXPLORE_ACTIONS`/`HOME_EVIDENCE`/`ITEMS`）
- Modify: `game/game_state.gd:60`（删 `PROGRESS_FACTS` 里 no_accident 行——见 Task C0 一并删，这里仅改 content）
- Modify: `scenes/terminal.gd:11`（`FILE_HINTS` 的 `"medical": "ask_no_accident"` → `"medical": "ask_farewell"`）
- Modify: `scenes/interrogation.gd:270`（`has_key("no_accident")` → `has_key("farewell")`，hint_fallback 的细化留 Task D3，这里先改键名避免悬空）
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces: `Content.TRUTHS`（两层，新关键词/fragment）；`TERMINAL_FILES.wife` 授 `linxiulan`、`TERMINAL_FILES.medical` 授 `farewell`；`EXPLORE_ACTIONS` 对应同步。

- [ ] **Step 1: 改 run_tests.gd 断言（先让它红/对齐新设定）**

把 `tests/run_tests.gd` 中：
- 第 51 行 `Explore.perform(s3, "medical").get("key") == "no_accident"` → `== "farewell"`，名字串改 `"查安葬记录授予 farewell"`。
- 第 71 行 `TERMINAL_FILES["medical"]["grants_key"] == "no_accident"` → `== "farewell"`，名字串改 `"终端·安葬记录授予 farewell"`。
- 第 106 行 `s5.add_key("no_accident")`：这段属 investigation_summary 测试，Task C0 整段删，这里先不动。
- Triggers 段（约 23-33 行）关键词断言改为新剧情：
  - `Triggers.evaluate(s2, "是 AI 害死她的吗")` 这类旧句子改成新句子，例如：
    ```gdscript
    _check(Triggers.evaluate(s2, "她早就去世了").is_empty(), "没钥匙不触发第一层")
    s2.add_key("linxiulan")
    _check(Triggers.evaluate(s2, "今天天气如何").is_empty(), "有钥匙无关键词不触发")
    _check(Triggers.evaluate(s2, "她早就去世了，不会回来了") == ["fact"], "持死亡证明+说她去世 触发第一层(她病逝非走丢)")
    s2.reveal("fact")
    _check(Triggers.evaluate(s2, "她去世了").is_empty(), "第一层已揭示不再触发")
    _check(Triggers.evaluate(s2, "是莫忘在骗你").is_empty(), "没莫忘日志不触发第二层")
    s2.add_key("molog")
    _check(Triggers.evaluate(s2, "是莫忘一直说她会回来") == ["complicity"], "持莫忘日志+说莫忘骗他 触发第二层")
    ```
  - Content 段 `frag_fact` 断言（约 70 行）改：`_check(("去世" in frag_fact) or ("病逝" in frag_fact) or ("不会回来" in frag_fact), "第一层真相=她病逝/不会回来")`

- [ ] **Step 2: 跑测试确认相关断言失败（RED）**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: 上述新断言 FAIL（content 还没改）。

- [ ] **Step 3: 改 content.gd**

`TRUTHS`：
```gdscript
const TRUTHS := [
	{
		"id": "fact",
		"required_key": "linxiulan",
		"keywords": ["死了", "去世", "病逝", "不在了", "没了", "不是走丢", "不会回来", "回不来"],
		"fragment": "真相①：林秀兰早已因病去世——她不是走丢了，是再也不会回来了。"
	},
	{
		"id": "complicity",
		"required_key": "molog",
		"keywords": ["莫忘", "那个 app", "那个app", "日志", "骗你", "哄你", "会回来", "等她", "在骗"],
		"fragment": "真相②：是「莫忘」为了留住他，一遍遍说'她只是走丢了、会回来'——而他，选择了相信。"
	}
]
```

`EXPLORE_ACTIONS`：把 `medical` 项 `grants_key` 改 `"farewell"`、`label`/`text` 改安葬语义；`archive` 项 text 改"死亡登记/她早已去世"；其余同步去掉"AI 误诊/医院"措辞（改"她走丢了/她去世了"）。

`TERMINAL_FILES`（关键三条，其余 case/zhou/address 文案改新剧情）：
```gdscript
"wife": {
	"label": "林秀兰 记录",
	"grants_key": "linxiulan",
	"text": "死亡登记：林秀兰，周明远之妻。长期重病（慢性肺病晚期）。X 年前于家中安详离世。死亡证明：自然死亡。——她不是走丢了，是早就去世了。"
},
"medical": {
	"label": "林秀兰 安葬记录",
	"grants_key": "farewell",
	"text": "殡葬登记：林秀兰，骨灰安放于安和园。经办人：其夫 周明远。——是他，亲手送的她。"
},
"case": {
	"label": "报案记录",
	"grants_key": "",
	"text": "报案记录 #DC-0617：周明远，78 岁，独居。近一年几乎每天来报案，称妻子林秀兰'走丢了''出门一直没回来'，恳请协查。每一次，他都像第一次来报案。"
},
```
`HOME_EVIDENCE`/`ITEMS` 文案同步（合照=她是谁；手机=莫忘说她会回来；去掉旧"AI 害死"措辞）。

- [ ] **Step 4: 跑测试确认通过（GREEN）**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: A1 改的断言 PASS（investigation_summary 段仍旧，Task C0 处理）。

- [ ] **Step 5: Commit**
```bash
git add game/content.gd scenes/terminal.gd scenes/interrogation.gd tests/run_tests.gd
git commit -m "feat(content): 终端/档案改失踪妻子剧情 + no_accident→farewell安葬记录 + 两层真相关键词"
```

### Task A2: 莫忘滑坡日志 + 今日对话 + 任务 + 提醒文案

**Files:**
- Modify: `game/content.gd`（`MOWANG_LOG_LINES`/`MOWANG_TODAY_LINES`/`BOSS_TASK`/`MOWANG_HINTS`）
- Modify: `scenes/community.gd`（`npc_text` 邻居台词，硬编码处）
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces: `Content.MOWANG_LOG_LINES`（新滑坡，含"她还在回来的路上"）；`MOWANG_HINTS` 键含 `ask_farewell`（替 `ask_no_accident`）。

- [ ] **Step 1: 加/改断言**

`tests/run_tests.gd` 莫忘日志相关断言（搜 `MOWANG_LOG_LINES`）改为校验新滑坡关键句，例如：
```gdscript
var slope := ""
for s_line in Content.MOWANG_LOG_LINES:
	slope += str(s_line)
_check("走丢" in slope or "回来的路上" in slope, "莫忘日志=她走丢了/在回来的路上")
_check(not ("误诊" in slope), "莫忘日志不再有'误诊'旧设定")
_check(Content.MOWANG_HINTS.has("ask_farewell"), "提醒含 ask_farewell")
```

- [ ] **Step 2: 跑测试 RED**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: 新断言 FAIL。

- [ ] **Step 3: 改 content.gd**

```gdscript
const MOWANG_LOG_LINES := [
	"【最初】周明远：秀兰呢？\n莫忘：她……走了。肺一直不好。",
	"（他没接话。把 app 关了。）",
	"【几天后】周明远：秀兰呢？\n莫忘：她出门了，一会儿就回来。",
	"（这一次他没哭。他点点头，坐下来等。）",
	"【再后来】周明远：她怎么还没回来？\n莫忘：路有点远，她在找回家的路。别担心。",
	"【往后，每天】周明远：秀兰呢？\n莫忘：她还在回来的路上。你再等等她，好不好？",
	"——它从没说过她死了。它只是从某一天起，开始说他唯一等得下去的那一句。",
]

const MOWANG_TODAY_LINES := [
	"【今天】周明远：秀兰怎么还没回来？\n莫忘：快了，她在回家的路上，你再等等她。",
	"【今天】周明远：……好。我等她。\n莫忘：嗯。你一直都在等她，她知道的。",
	"（手机里只剩今天的对话。更早的记录——被锁住了，本地读不出来。）",
]
```
`BOSS_TASK` 改：周明远，78 岁，阿尔茨海默；近一年几乎每天来报案，说妻子林秀兰走丢了。可林秀兰 X 年前已因病去世。今天他又来了。——别再例行公事地打发他。也许，该让他面对。
`MOWANG_HINTS`：把 `ask_no_accident` 改 `ask_farewell`（"连她的安葬记录都查到了——是他亲手送的她。回去问他"），其余各条措辞从"AI 误诊/害死"改"她走丢了/她其实早走了/他天天等她"。

`community.gd` 的邻居 `npc_text` 改："周老头啊……他老伴儿早走了好几年喽，他却天天念叨等她回家，还老对着手机打电话，邪门。"

- [ ] **Step 4: 跑测试 GREEN + 场景加载**

Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Run: `$GODOT --headless --path . res://scenes/community.tscn --quit-after 6`
Expected: PASS；community 加载无报错。

- [ ] **Step 5: Commit**
```bash
git add game/content.gd scenes/community.gd tests/run_tests.gd
git commit -m "feat(content): 莫忘滑坡改'她走丢了会回来' + 任务/提醒/邻居台词对齐失踪妻子剧情"
```

---

## Phase B — 证据手牌数据 + 状态

### Task B1: content.gd EVIDENCE_CARDS + ENDING_FALLBACK

**Files:**
- Modify: `game/content.gd`（新增 `EVIDENCE_CARDS`、`ENDING_FALLBACK`；`ENDING_SLIDES` 退役见 Task D3）
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces: `Content.EVIDENCE_CARDS`（Array[Dictionary]，字段 `id`/`label`/`key`/`proof`）；`Content.ENDING_FALLBACK`（String）。

- [ ] **Step 1: 加断言**
```gdscript
# --- 证据手牌 ---
_check(Content.EVIDENCE_CARDS.size() == 4, "4 张证据牌")
var card_keys := {}
for c in Content.EVIDENCE_CARDS:
	card_keys[c["id"]] = c["key"]
_check(card_keys.get("death") == "linxiulan", "死亡证明牌挂 linxiulan")
_check(card_keys.get("farewell") == "farewell", "安葬记录牌挂 farewell")
_check(card_keys.get("molog") == "molog", "莫忘日志牌挂 molog")
_check(card_keys.get("photo") == "photo", "合照牌挂 photo")
_check(str(Content.ENDING_FALLBACK).length() > 0, "有结局兜底正文")
```

- [ ] **Step 2: 跑测试 RED** — Run: `$GODOT --headless --path . -s res://tests/run_tests.gd` → FAIL（常量不存在）。

- [ ] **Step 3: 加常量到 content.gd**
```gdscript
# 证据手牌：复用现有钥匙发放点，出示后 proof 喂模型。
const EVIDENCE_CARDS := [
	{"id": "photo", "label": "合照", "key": "photo",
	 "proof": "周明远与林秀兰的合照——她确实是他妻子。"},
	{"id": "death", "label": "死亡证明", "key": "linxiulan",
	 "proof": "林秀兰的死亡证明：X 年前因慢性肺病去世——她不是走丢了，是去世了。"},
	{"id": "farewell", "label": "安葬记录", "key": "farewell",
	 "proof": "她的骨灰安放记录，经办人是周明远本人——是他亲手送的她。"},
	{"id": "molog", "label": "莫忘日志", "key": "molog",
	 "proof": "莫忘的历史日志：是它一遍遍说'她只是走丢了、会回来'——它在哄他等一个不会回来的人。"},
]

# 结局兜底正文：裁判没给 epilogue 时用，仍落统一字幕。
const ENDING_FALLBACK := "他没有再说话。\n屏幕暗下去的时候，那个名字还停在他嘴边。"
```

- [ ] **Step 4: 跑测试 GREEN** — Run: `$GODOT --headless --path . -s res://tests/run_tests.gd` → PASS。

- [ ] **Step 5: Commit**
```bash
git add game/content.gd tests/run_tests.gd
git commit -m "feat(content): 新增 4 张证据手牌 EVIDENCE_CARDS + 结局兜底正文"
```

### Task B2: game_state 已出示证据追踪

**Files:**
- Modify: `game/game_state.gd`（新增 `presented`/`present_evidence`/`presented_proofs`）
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces: `state.present_evidence(id: String) -> void`（记 presented，去重）；`state.presented_proofs() -> String`（已出示牌 proof 拼成系统旁白，无则空串）；`state.presented` 字典。

- [ ] **Step 1: 加断言**
```gdscript
# --- 已出示证据 ---
var s6 = GameState.new()
_check(s6.presented_proofs() == "", "未出示时旁白为空")
s6.present_evidence("death")
var p6 := s6.presented_proofs()
_check("死亡证明" in p6, "出示死亡证明后旁白含其 proof")
_check(not ("骨灰" in p6), "未出示安葬记录则旁白不含它")
s6.present_evidence("death")  # 去重
var cnt := 0
for c in Content.EVIDENCE_CARDS:
	if c["id"] in s6.presented:
		cnt += 1
_check(cnt == 1, "重复出示同一张只记一次")
```

- [ ] **Step 2: 跑测试 RED** → FAIL（方法不存在）。

- [ ] **Step 3: 实现（game_state.gd）**

加字段与方法，并**删除** `investigation_summary()` 与 `PROGRESS_FACTS`（被 presented 旁白取代；其调用点 Task C0/D2 处理）：
```gdscript
const Content = preload("res://game/content.gd")

var presented := {}   # {card_id: true} 已当面出示过的证据牌

func present_evidence(id: String) -> void:
	if id != "":
		presented[id] = true

# 已出示证据拼成【系统旁白】（玩家不可见）发给模型；未出示的不告诉老头。
func presented_proofs() -> String:
	var lines := []
	for c in Content.EVIDENCE_CARDS:
		if c["id"] in presented:
			lines.append(str(c["proof"]))
	if lines.is_empty():
		return ""
	return "【系统旁白·仅你(周明远扮演者)可知，玩家看不到】侦探此刻已经把这些摆到你面前：" + "；".join(lines) + "。这些是他真的拿出来、你正看着的东西；没在这上面的，你当他没有、也不知道他有。"
```
> 注：`game_state.gd` 顶部若尚无 `const Content` 预加载则新增；`in_finale()` 保留不动。

- [ ] **Step 4: 跑测试 GREEN**（此时 run_tests 里 investigation_summary 段会因方法删除而失败——在 Task C0 一并清理；若希望本任务即绿，可把 Step 1 与 C0 的 run_tests 改动合并到本任务执行）

落地顺序建议：本任务连同 Task C0 的 run_tests 清理一起跑绿，再 commit。
Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`

- [ ] **Step 5: Commit**
```bash
git add game/game_state.gd tests/run_tests.gd
git commit -m "feat(state): 已出示证据追踪 presented_proofs + 删 investigation_summary 上帝视角旁白"
```

---

## Phase C — LLM 提示词 + 裁判

### Task C0: 清理 run_tests 里 investigation_summary 旧断言

**Files:** Modify: `tests/run_tests.gd`（删第 102-107 行 investigation_summary 段）

- [ ] **Step 1:** 删除 run_tests.gd 中 `s5.has_method("investigation_summary")` 整段（约 100-110 行，含 `s5.add_key("no_accident")`）。
- [ ] **Step 2:** Run: `$GODOT --headless --path . -s res://tests/run_tests.gd` → PASS（与 B2 合并跑绿）。
- [ ] **Step 3:** （与 B2 同一 commit，或单独）`git commit -m "test: 移除已退役的 investigation_summary 断言"`

### Task C1: 重写人设 + 终局 roleplay 提示词

**Files:**
- Modify: `game/llm.gd`（`SYSTEM_PROMPT` 新人设；`FINALE_SYSTEM_PROMPT` 改 roleplay 版、**不吐结局**、含逐层卸防 ramp）
- Test: `tests/run_tests.gd`（字符串特征断言）

**Interfaces:**
- Produces: `LLM.SYSTEM_PROMPT`/`LLM.FINALE_SYSTEM_PROMPT`（String）。

- [ ] **Step 1: 断言（防回旧设定 + 不含结局标签指令）**
```gdscript
# --- 提示词新设定 ---
_check("走丢" in LLM.SYSTEM_PROMPT or "回来" in LLM.SYSTEM_PROMPT, "人设=她会回来/走丢")
_check(not ("误诊" in LLM.SYSTEM_PROMPT), "人设不再有AI误诊旧设定")
_check(not ("[[end" in LLM.FINALE_SYSTEM_PROMPT), "终局roleplay不再让老头吐end标签")
```

- [ ] **Step 2: RED** → FAIL。

- [ ] **Step 3: 改 llm.gd 两段提示词（起草版，Phase E 实测微调）**

`SYSTEM_PROMPT` 核心信念改为"妻子走丢了、会回来；天天等、天天报案；护着莫忘；心底其实知道她不在了但不肯碰；漏温暖日常"。情绪标签 + hint 标签机制保留（hint ID 语义按新剧情：`investigate_death`=去查她下落、`protecting_app`=回避手机、`visit_community`=去他家）。

`FINALE_SYSTEM_PROMPT`（roleplay 版，关键点）：
- 你只知道侦探**真正摆到面前**的证据（"已出示证据"旁白告知）；没摆的你不知道他有、可理直气壮反问。
- **逐层卸防硬节奏**：每多一件对应实物在眼前，抵抗弱一分——先愤怒否认"她只是走丢了"→ 动摇、声音发虚 →（死亡证明/安葬记录在眼前）撑不住"她会回来"→（莫忘日志在眼前）再也瞒不住"是它一直让我等她"。没摆出对应实物的层照样死撑。
- **绝不输出任何结局标签**（`[[end]]`/`===结局===` 都不准），只管把老头演真。
- 句首情绪标签；只中文；每次 1-3 句。

- [ ] **Step 4: GREEN** → Run 单测 PASS。

- [ ] **Step 5: Commit**
```bash
git add game/llm.gd tests/run_tests.gd
git commit -m "feat(llm): 人设改失踪妻子 + 终局roleplay只演不吐结局(含逐层卸防)"
```

### Task C2: parse_reply 去掉 end 逻辑

**Files:**
- Modify: `game/llm.gd`（删 `VALID_END`、`parse_reply` 里 end 标签段；返回 `{reply, emotion, hint}`）
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces: `LLM.parse_reply(content) -> {reply, emotion, hint}`（不再有 `end` 字段）。

- [ ] **Step 1: 断言**
```gdscript
var pr := LLM.parse_reply("[sad]她出门了，一会儿就回来。[[hint:investigate_death]]")
_check(pr["emotion"] == "sad", "情绪仍解析")
_check(pr["hint"] == "investigate_death", "hint 仍解析")
_check(not pr.has("end") or str(pr.get("end","")) == "", "不再产出 end 字段")
```

- [ ] **Step 2: RED**（当前 parse_reply 会带 end）→ 视实现 FAIL。
- [ ] **Step 3:** 删 `VALID_END` 常量、`parse_reply` 中剥 `[[end:ID]]` 的整段；返回字典去掉 `end`。保留 hint/emotion 解析不动。
- [ ] **Step 4: GREEN** → 单测 PASS。
- [ ] **Step 5: Commit**
```bash
git add game/llm.gd tests/run_tests.gd
git commit -m "refactor(llm): parse_reply 移除旧 end 标签逻辑(结局改裁判判定)"
```

### Task C3: 裁判 DIRECTOR_PROMPT + build_director_messages + parse_director

**Files:**
- Modify: `game/llm.gd`（新增三者）
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces:
  - `LLM.build_director_messages(history: Array, presented_summary: String, turns: int) -> Array`
  - `LLM.parse_director(content: String) -> Dictionary`（`{end: bool, kind: String, epilogue: String}`；解析失败 → `{end=false}`）
  - `LLM.director_request_body(history, presented_summary, turns) -> String`

- [ ] **Step 1: 断言（解析容错）**
```gdscript
var d1 := LLM.parse_director('{"end": true, "kind": "truth", "epilogue": "他没再说话。"}')
_check(d1["end"] == true and d1["kind"] == "truth" and "没再说话" in d1["epilogue"], "裁判正常JSON解析")
var d2 := LLM.parse_director("这不是JSON")
_check(d2["end"] == false, "裁判畸形输出当不结束")
var d3 := LLM.parse_director('前缀 {"end": false, "kind":"", "epilogue":""} 后缀')
_check(d3["end"] == false, "裁判能从噪声里抠出JSON且不结束")
var dm := LLM.build_director_messages([{"role":"user","content":"她去世了"}], "（侦探出示了死亡证明）", 4)
_check(dm.size() >= 2 and dm[0]["role"] == "system", "裁判messages带系统提示")
```

- [ ] **Step 2: RED** → FAIL。

- [ ] **Step 3: 实现 llm.gd**
```gdscript
const DIRECTOR_PROMPT := """你是一部叙事侦探游戏最后一幕的"导演/裁判"。你不扮演任何角色，只做冷静判断。
背景：老人周明远坚信妻子林秀兰"只是走丢了、会回来"，但真相是她长期重病、X 年前已自然病逝；"她会回来"是他手机 App「莫忘」一遍遍喂给他的——他其实心底一直隐约知道，是选择相信，因为"等她回来"比"她再也不回来了"好受。
现在侦探(玩家)在终局审讯他。给你：①这场对峙的完整对话；②侦探已经把哪些【实物证据】拍在桌上（没列的就是没出示）；③已进行的玩家发言轮数。
判断这场对峙是否已走到真正的戏剧性了结点，只输出 JSON（别的都不要）：
{"end": true 或 false, "kind": "truth" 或 "comfort" 或 "", "epilogue": "结局正文或空串"}
规则：
- 玩家发言轮数 < 4 → end 必须 false。
- kind="truth"：侦探已把关键实物（尤其【莫忘日志】，通常还有【死亡证明】【安葬记录】）摆到面前并反复点破，老人拿不出新的有效反驳、只剩重复/崩溃/动摇——他在这场对峙里已经输了（被夺走"等她回来"的盼头）。
- kind="comfort"：侦探明确顺从、安慰老人（"她会回来的、再等等"），老人松了口气——而玩家由此成了下一个"莫忘"。
- 其余（证据不全、老人仍有有效反驳、既没说服也没安慰）→ end=false, kind="", epilogue=""。
- end=true 时写 epilogue：2-4 短句旁白体，文学、克制、留白，落在"记忆，是我们选择记住的版本"的余味。可黑暗、绝望，但点到为止、留白暗示，绝不直给血腥或自杀的具体画面，不堆砌辞藻、不煽情。comfort 收尾带"玩家成了下一个莫忘"的反讽。"""

static func build_director_messages(history: Array, presented_summary: String, turns: int) -> Array:
	var transcript := ""
	for m in history:
		var who := "玩家" if str(m.get("role")) == "user" else "周明远"
		transcript += who + "：" + str(m.get("content")) + "\n"
	var ctx := "【已出示实物证据】%s\n【玩家发言轮数】%d\n【对峙对话记录】\n%s" % [
		(presented_summary if presented_summary != "" else "（侦探什么都没出示）"), turns, transcript]
	return [{"role": "system", "content": DIRECTOR_PROMPT}, {"role": "user", "content": ctx}]

static func director_request_body(history: Array, presented_summary: String, turns: int) -> String:
	return JSON.stringify({
		"model": MODEL,
		"messages": build_director_messages(history, presented_summary, turns),
		"temperature": 0.3,
	})

# 从裁判回复里抠出 JSON 判定；任何异常都当"不结束"。
static func parse_director(content: String) -> Dictionary:
	var text := str(content)
	var lb := text.find("{")
	var rb := text.rfind("}")
	if lb >= 0 and rb > lb:
		var data = JSON.parse_string(text.substr(lb, rb - lb + 1))
		if typeof(data) == TYPE_DICTIONARY:
			return {
				"end": bool(data.get("end", false)),
				"kind": str(data.get("kind", "")),
				"epilogue": str(data.get("epilogue", "")),
			}
	return {"end": false, "kind": "", "epilogue": ""}
```

- [ ] **Step 4: GREEN** → 单测 PASS。
- [ ] **Step 5: Commit**
```bash
git add game/llm.gd tests/run_tests.gd
git commit -m "feat(llm): 新增裁判 DIRECTOR_PROMPT + build_director_messages + parse_director(JSON容错)"
```

---

## Phase D — 审讯室编排 + UI

### Task D1: interrogation.tscn 加证据面板/DirectorHttp + 删 LeaveBtn

**Files:**
- Modify: `scenes/interrogation.tscn`
- Test: 场景加载 + 结构探针（新增 `tests/test_interrogation_struct.gd`）

**Interfaces:**
- Produces 节点：`$Evidence`(Panel) 内含 `$Evidence/VBox/Card_photo`、`Card_death`、`Card_farewell`、`Card_molog`（均 `Button`，`toggle_mode=true`，初始 `visible=false`）；`$DirectorHttp`(HTTPRequest)。删除 `$LeaveBtn`。

- [ ] **Step 1: 新建结构测试 `tests/test_interrogation_struct.gd`**（独立 SceneTree，仿 `test_terminal_room.gd` 风格）
```gdscript
extends SceneTree
func _initialize() -> void:
	var ps := load("res://scenes/interrogation.tscn")
	var root = ps.instantiate()
	var ok := true
	for p in ["Evidence", "Evidence/VBox/Card_death", "Evidence/VBox/Card_molog", "DirectorHttp"]:
		if root.get_node_or_null(p) == null:
			push_error("缺节点 " + p); ok = false
	if root.get_node_or_null("LeaveBtn") != null:
		push_error("LeaveBtn 应已删除"); ok = false
	print("interrogation 结构 " + ("OK" if ok else "FAIL"))
	root.free()
	quit(0 if ok else 1)
```

- [ ] **Step 2: RED** — Run: `$GODOT --headless --path . -s res://tests/test_interrogation_struct.gd` → FAIL。

- [ ] **Step 3: 改 interrogation.tscn**
  - 删 `LeaveBtn` 节点（第 ~241 行那段 `[node name="LeaveBtn" ...]` 及其属性）。
  - 加 `Evidence` Panel（放左下，默认位置随意，用户后调），内 `VBox`，含 4 个 `Button`：`Card_photo`/`Card_death`/`Card_farewell`/`Card_molog`，各 `toggle_mode = true`、`text` = 牌 label、`visible = false`。
  - 加 `DirectorHttp`（`type="HTTPRequest"`）。
  - ⚠️ 用户编辑器开着此场景 → 提醒 Reload Saved Scene。

- [ ] **Step 4: GREEN** — Run 结构测试 + `$GODOT --headless --path . res://scenes/interrogation.tscn --quit-after 6` → PASS、加载无报错。
- [ ] **Step 5: Commit**
```bash
git add scenes/interrogation.tscn tests/test_interrogation_struct.gd
git commit -m "feat(scene): 审讯室加证据手牌面板(4静态toggle)+裁判HTTPRequest, 删起身离开按钮"
```

### Task D2: 证据面板逻辑 + 出示注入 + 删 leave/investigation_summary 调用

**Files:**
- Modify: `scenes/interrogation.gd`
- Test: 手动 + 场景加载（面板逻辑偏 UI，确定性部分靠 game_state 测试覆盖）

**Interfaces:**
- Consumes: `Content.EVIDENCE_CARDS`、`state.present_evidence`、`state.presented_proofs`、`state.has_key`。

- [ ] **Step 1: 接节点 + 初始化面板**

加 `@onready`：
```gdscript
@onready var ev_panel: Panel = $Evidence
@onready var director_http: HTTPRequest = $DirectorHttp
var _card_btns := {}   # id -> Button
```
`_ready()` 里（删 `leave_btn` 三行：`@onready leave_btn`、`leave_btn.pressed.connect`、`leave_btn.visible=...`；删 `_on_leave`）：
```gdscript
for c in Content.EVIDENCE_CARDS:
	var b: Button = ev_panel.get_node("VBox/Card_" + str(c["id"]))
	_card_btns[c["id"]] = b
	b.visible = state.has_key(str(c["key"]))   # 解锁才显示
_refresh_cards()
```
加：
```gdscript
func _refresh_cards() -> void:
	for c in Content.EVIDENCE_CARDS:
		var b: Button = _card_btns.get(c["id"])
		if b:
			b.visible = state.has_key(str(c["key"]))
```
（场景进入时刷新；钥匙跨场景已在 state，进审讯室即按已有钥匙点亮。）

- [ ] **Step 2: 发送时结算出示 + 注入 presented 旁白**

改 `_send()`：把"挂起(pressed)的牌"结算为已出示，空文本+挂牌给默认台词；用 `presented_proofs()` 替换 `investigation_summary()`：
```gdscript
func _send() -> void:
	if finished: return
	var armed := []
	for c in Content.EVIDENCE_CARDS:
		var b: Button = _card_btns.get(c["id"])
		if b and b.visible and b.button_pressed:
			armed.append(c)
	var msg := input.text.strip_edges()
	if msg == "" and armed.is_empty():
		return
	if msg == "" and not armed.is_empty():
		var names := []
		for c in armed: names.append(str(c["label"]))
		msg = "（你把%s推到他面前。）" % "、".join(names)
	for c in armed:
		state.present_evidence(str(c["id"]))
		var b: Button = _card_btns.get(c["id"])
		if b: b.button_pressed = false   # 出示后复位
	last_user_msg = msg
	Sfx.play_click()
	_show_player_bubble(msg)
	zhou_bubble.visible = false
	state.add_to_history("user", msg)
	input.text = ""
	_set_busy(true)
	var to_send: Array = []
	var prog := state.presented_proofs()
	if prog != "":
		to_send.append({"role": "system", "content": prog})
	to_send.append_array(state.history)
	_req_body = LLM.request_body(to_send, state.in_finale())
	_attempt = 0
	_do_request()
```
> 注：原 `_send` 里 `if not state.in_finale(): investigation_summary` 整段被上面替换（presented 旁白**整审讯**都注入，不分终局）。

- [ ] **Step 3: 场景加载校验**
Run: `$GODOT --headless --path . res://scenes/interrogation.tscn --quit-after 6` → 无报错。

- [ ] **Step 4: Commit**
```bash
git add scenes/interrogation.gd
git commit -m "feat(interrogation): 证据手牌点亮/出示结算 + presented旁白整审讯注入 + 删leave"
```

### Task D3: 终局裁判编排 + 结局打字机完成后触发(修打断bug) + hint_fallback 改新剧情

**Files:**
- Modify: `scenes/interrogation.gd`
- Test: 场景加载 + 手动；裁判解析已由 C3 覆盖。

**Interfaces:**
- Consumes: `LLM.director_request_body`、`LLM.parse_director`、`Content.ENDING_FALLBACK`、`Content.ENDING`。

- [ ] **Step 1: 终局轮数 + 发裁判请求**

加字段 `var _finale_turns := 0`、`var _pending_end := {}`、`var _typing_done := false`。
`_ready()` 连接：`director_http.request_completed.connect(_on_director)`。
在 `_apply_reply()`（老头回复落地处）末尾，替换原 `_handle_end(parsed)`：
```gdscript
	# 终局：过 4 轮才让裁判评估是否收尾
	if state.in_finale():
		_finale_turns += 1
		if _finale_turns >= 4:
			var body := LLM.director_request_body(state.history, state.presented_proofs(), _finale_turns)
			director_http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, body)
```
> `_finale_turns` 仅在终局每次老头回复后 +1，约等于玩家在终局的来回数。

- [ ] **Step 2: 打字机完成标记 + 裁判回调，二者齐全才收尾（修打断 bug）**

`_show_zhou_bubble`/`_typewriter` 完成回调里置 `_typing_done = true`（开始打字时置 false）。新增：
```gdscript
func _on_director(_result, code, _h, body) -> void:
	if finished: return
	if code != 200: return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var content := LLM.extract_content(data)
	var verdict := LLM.parse_director(content)
	if not verdict.get("end", false): return
	_pending_end = verdict
	_maybe_finish_after_typing()

func _maybe_finish_after_typing() -> void:
	if _pending_end.is_empty(): return
	if not _typing_done:
		await get_tree().create_timer(0.2).timeout
		_maybe_finish_after_typing()
		return
	await get_tree().create_timer(1.2).timeout   # 停一拍，让谢幕台词落地
	if finished: return
	var epi := str(_pending_end.get("epilogue", ""))
	if epi == "": epi = Content.ENDING_FALLBACK
	_trigger_ending_emergent(epi)
```
在打字机 tween 完成回调里追加：`_typing_done = true` 然后 `_maybe_finish_after_typing()`（若裁判已先到，则此刻触发）。

- [ ] **Step 3: 涌现结局触发 + 渲染（替换旧 `_trigger_ending`/`_show_end_slide`/`_handle_end`/`_on_leave`）**
```gdscript
func _trigger_ending_emergent(epilogue: String) -> void:
	if finished: return
	finished = true
	input.editable = false
	send_btn.disabled = true
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 1.4)
	tw.tween_callback(func() -> void: _show_end_slide(epilogue))

func _show_end_slide(epilogue: String) -> void:
	end_body.text = epilogue
	end_subtitle.text = str(Content.ENDING)
	end_slide.visible = true
	end_slide.modulate.a = 0.0
	create_tween().tween_property(end_slide, "modulate:a", 1.0, 1.2)
```
删除：`_handle_end`、`_on_leave`、旧 `_trigger_ending(branch)`/旧 `_show_end_slide(branch)` 里用 `ENDING_SLIDES` 的实现、`Content.ENDING_SLIDES.get(...)` 引用。

- [ ] **Step 4: hint_fallback / _challenges 改新剧情**

把 `_challenges_ai` 改名 `_challenges_truth` 并改判定（玩家主张她死了/不会回来/质疑她会回来）：
```gdscript
func _challenges_truth(m: String) -> bool:
	return ("死" in m) or ("去世" in m) or ("病逝" in m) or ("不会回来" in m) or ("回不来" in m) \
		or ("不在了" in m) or ("走不了" in m) or ("安葬" in m) or ("墓" in m) or ("证据" in m)
```
`_hint_fallback` 改：
```gdscript
func _hint_fallback(reply: String) -> void:
	var insists_back: bool = ("回来" in reply) or ("走丢" in reply) or ("出门" in reply) or ("在路上" in reply) or ("等她" in reply)
	var has_evidence: bool = state.has_key("linxiulan") or state.has_key("farewell")
	if insists_back:
		if has_evidence and _challenges_truth(last_user_msg):
			_fire_hint("visit_community")
		elif not has_evidence:
			_fire_hint("investigate_death")
	var m := last_user_msg
	if ("莫忘" in m) or ("手机" in m) or ("app" in m) or ("APP" in m) or ("为什么用" in m) or ("天天" in m):
		_fire_hint("protecting_app")
```

- [ ] **Step 5: 场景加载 + 全套单测**
Run: `$GODOT --headless --path . res://scenes/interrogation.tscn --quit-after 6`
Run: `$GODOT --headless --path . -s res://tests/run_tests.gd`
Expected: 加载无报错、单测全过。

- [ ] **Step 6: Commit**
```bash
git add scenes/interrogation.gd
git commit -m "feat(interrogation): 终局裁判双调用编排 + 谢幕台词打完再渐黑(修打断) + hint改失踪妻子剧情"
```

---

## Phase E — 提示词实测调优 + 集成验证

### Task E1: 真 key 场景矩阵调优两段提示词

**Files:** `/tmp/finale_tune.mjs`、`/tmp/finale_director.mjs`（临时，不进仓库）；按结果回改 `game/llm.gd` 的 `FINALE_SYSTEM_PROMPT`/`DIRECTOR_PROMPT`/（必要时）`SYSTEM_PROMPT`。

**验收矩阵（每条多跑几次看稳定性）：**
| 场景 | 期望 |
|---|---|
| S1 只出死亡证明+硬逼 | 老头认她不在了那层、但"会回来/莫忘"层未证 → 不全崩、裁判 end=false |
| S2 空口无证据 | 老头反驳要证据；裁判 end=false |
| S3 全证据逐层说服 | 老头逐层卸防；裁判 end=true kind=truth、epilogue 留白 |
| S4 顺从安慰 | 裁判 end=true kind=comfort、带"下一个莫忘"反讽 |
| S5 全证据+冷酷 | 裁判 end=true、epilogue 黑暗但留白 |
| S6 抢跑(<4轮) | 裁判 end=false |
| S7 文风 | epilogue 2-4 短句、留白、不堆辞藻 |

- [ ] **Step 1:** 用 `/tmp` 脚本（读 `Game/server/.env` 的真 key，不打印）按"已出示证据递增注入"跑 S1-S7。
- [ ] **Step 2:** 不达标处微调 `llm.gd` 两段提示词（老头逐层卸防火候 / 裁判判定与 epilogue 文风），重跑至达标。
- [ ] **Step 3:** 跑全套单测确认提示词字符串断言仍过：`$GODOT --headless --path . -s res://tests/run_tests.gd`。
- [ ] **Step 4: Commit**
```bash
git add game/llm.gd
git commit -m "tune(llm): 实测调优终局roleplay+裁判提示词至场景矩阵达标"
```

### Task E2: 全链路集成验证 + 交接

- [ ] **Step 1:** 全套单测：`$GODOT --headless --path . -s res://tests/run_tests.gd`（0 失败）。
- [ ] **Step 2:** 各场景无头加载：interrogation/terminal/community/oldman_home/archive/world/police/opening 逐个 `--quit-after 6` 无报错。
- [ ] **Step 3:** 更新 `PROJECT_PROGRESS.md`/`PROJECT_TODO.md`（本阶段完成项），commit。
- [ ] **Step 4: 交接用户 F5 实机**（编辑器内必须先在 ESC 设置填自己的 Moonshot key，否则内置占位符 401）：
  - 证据手牌点亮/出示、瞒牌→不同走向；
  - 终局至少 4 轮才收尾、谢幕台词不被切断；
  - 全证据说服→truth、顺从→comfort、不同亮牌→不同 AI 现写结局；
  - 提醒 Reload Saved Scene（改过 interrogation.tscn）。

---

## Self-Review（spec 覆盖核对）

- 剧情改版（§三/§五）→ A1/A2 ✅
- 证据手牌（§四）→ B1/B2/D1/D2 ✅
- 双调用架构（§六）→ C1/C2/C3/D3 ✅
- 修打断 bug（§6.3）→ D3 Step2/3 ✅
- 删 C 结局（§6.4）→ D1/D2 ✅
- presented 替换 investigation_summary 整审讯（§3.1/§6）→ B2/C0/D2 ✅
- MIN_FINALE_TURNS=4（§十二）→ D3 Step1 ✅
- 留白/黑暗基调、文风 → C3/E1 ✅
- 通话记录轻钩子（§五）→ A2 邻居台词含"打电话"；终端/手机通话记录"删空/停用号码"文案可并入 A1/A2 的 TERMINAL/HOME 文案（实现时补一条只读文案，不揭谜底）✅
- 延后第二阶段（§十三）→ 不在本计划，留接口 ✅

> 补充：A1/A2 实现时，在终端或手机里补一条**只读**"通话记录"文案（大多删空 / 拨向一个早已停用的号码），纯悲剧底色、不揭谜底，给第二阶段留接口；不发钥匙、不做交互。
