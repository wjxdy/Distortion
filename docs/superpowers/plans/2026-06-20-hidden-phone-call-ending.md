# 隐藏电话结局线 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加一条隐藏支线结局——审讯中问老人"为什么总打电话"(解锁)再问"怎么打通的"(触发),进入诡异的"电话打通了"结局,AI 现写留白旁白 + 评称号。

**Architecture:** 两步确定性关键词触发(llm.gd 静态函数 + game_state flag);触发后老头一句脚本化收尾台词 → 发专属 `PHONE_EPILOGUE_PROMPT` 让 AI 现写诡异 epilogue → 复用现有 `_trigger_ending_emergent`(渐黑/称号/结局画面)。纯文字,无音频。

**Tech Stack:** Godot 4 (GDScript)、客户端直连 Moonshot、headless `run_tests.gd` 单测。

## Global Constraints

- **随时可触发**:不需要先拿 molog / 进终局;审讯室任意阶段都能走。
- **两步触发**:先问"打电话…"解锁(`phone_line_unlocked=true`),再问"怎么打通…"触发;**未解锁时问"怎么打通"不触发**。
- **诡异留白、不揭破、无音频**:epilogue 写"电话打通了"的瞬间,**不点破是谁接的**,不写"AI/合成语音",不写血腥/自杀具体画面,不写金句格言。
- **复用不重造**:结局渐黑/称号/EndSlide 全走现有 `_trigger_ending_emergent(epilogue)`;它读 `_pending_end.get("kind")` 发称号,故电话路径要先设 `_pending_end = {"end":true,"kind":"call","epilogue":...}`。
- **检测函数做成 `llm.gd` 静态函数**(便于 run_tests 直接调,无需实例化场景)。
- **项目铁律**:HTTPRequest 是逻辑节点,可在 `.tscn` 摆(现有 DirectorHttp/TitleHttp 即如此)。改 `.tscn` 后提醒用户 Reload。
- **测试命令**:
  `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
  全套:`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`(退出码 0=全过,末行 `结果: N 通过, M 失败`)
  审讯结构:`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_interrogation_struct.gd`
  场景冒烟:`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/interrogation.tscn --quit-after 4`
  (headless 的 "ObjectDB leaked"/"resources still in use" 是无害告警。)
- **真 key 实测**:仓库内置占位符会 401;实测需填真 Moonshot key。

---

### Task 1: 触发基元 — 检测静态函数 + 解锁 flag

**Files:**
- Modify: `Game/client/game/llm.gd`(文件末尾追加静态函数)
- Modify: `Game/client/game/game_state.gd`(加 flag)
- Test: `Game/client/tests/run_tests.gd`

**Interfaces:**
- Produces: `LLM.asks_why_calls(msg: String) -> bool`、`LLM.asks_how_connected(msg: String) -> bool`(纯关键词子串匹配)
- Produces: `GameState.phone_line_unlocked: bool`(默认 false,随新 GameState 重置)

- [ ] **Step 1: 写失败断言**

在 `tests/run_tests.gd` 末尾(`quit(...)` 之前)追加:

```gdscript
	# --- 隐藏电话线：触发检测 + 解锁门控 ---
	_check(LLM.asks_why_calls("你为什么老打电话") == true, "问为什么打电话→解锁命中")
	_check(LLM.asks_why_calls("你给谁打电话啊") == true, "打给谁→解锁命中")
	_check(LLM.asks_why_calls("今天天气怎么样") == false, "无关→不解锁")
	_check(LLM.asks_how_connected("你是怎么打通的") == true, "问怎么打通→触发命中")
	_check(LLM.asks_how_connected("电话接通了吗") == true, "接通了吗→触发命中")
	_check(LLM.asks_how_connected("她在哪") == false, "无关→不触发")
	var ps := GameState.new()
	_check(ps.phone_line_unlocked == false, "新局 phone_line_unlocked=false")
	_check((ps.phone_line_unlocked and LLM.asks_how_connected("怎么打通的")) == false, "未解锁→不触发")
	ps.phone_line_unlocked = true
	_check((ps.phone_line_unlocked and LLM.asks_how_connected("怎么打通的")) == true, "解锁后→触发")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL,`Invalid call ... 'asks_why_calls'` 或 `Invalid get index 'phone_line_unlocked'`

- [ ] **Step 3a: llm.gd 加两个静态检测函数**

在 `game/llm.gd` 末尾(`parse_reply` 之后)追加:

```gdscript
# —— 隐藏电话线：玩家发言关键词检测(确定性，便于单测) ——
# 第一步·问起他打电话的事 → 解锁这条线。
static func asks_why_calls(msg: String) -> bool:
	for kw in ["打电话", "老打电话", "总打电话", "常打电话", "打给谁", "给谁打", "电话"]:
		if msg.find(kw) >= 0:
			return true
	return false

# 第二步·追问怎么打通的 → (已解锁时)触发电话结局。
static func asks_how_connected(msg: String) -> bool:
	for kw in ["打通", "接通", "怎么打的通", "怎么打通", "通了吗", "能打通"]:
		if msg.find(kw) >= 0:
			return true
	return false
```

- [ ] **Step 3b: game_state.gd 加 flag**

在 `game/game_state.gd` 的 `var evidence_howto_shown := false` 那行**之后**加:

```gdscript
var phone_line_unlocked := false   # 隐藏电话线：玩家问过"他为什么打电话"后解锁；随新游戏=新 GameState 重置
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS,9 条新断言全 ok,0 失败

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/llm.gd Game/client/game/game_state.gd Game/client/tests/run_tests.gd
git commit -m "feat(电话线): LLM.asks_why_calls/asks_how_connected 检测 + game_state.phone_line_unlocked 解锁flag"
```

---

### Task 2: 提示词与文案 — 电话人设 + AI epilogue + 兜底

**Files:**
- Modify: `Game/client/game/llm.gd`(SYSTEM_PROMPT/FINALE_SYSTEM_PROMPT 加电话块 + 新增 epilogue 提示词/构建/解析)
- Modify: `Game/client/game/content.gd`(ENDING_PHONE_FALLBACK)
- Test: `Game/client/tests/run_tests.gd`

**Interfaces:**
- Produces: `LLM.PHONE_EPILOGUE_PROMPT: String`、`LLM.build_phone_epilogue_messages(history: Array) -> Array`、`LLM.phone_epilogue_request_body(history: Array) -> String`、`LLM.parse_phone_epilogue(content: String) -> String`
- Produces: `Content.ENDING_PHONE_FALLBACK: String`
- 修改:`LLM.SYSTEM_PROMPT` / `LLM.FINALE_SYSTEM_PROMPT` 均含电话元素("电话"+"打通")

- [ ] **Step 1: 写失败断言**

在 `tests/run_tests.gd` 接 Task 1 断言后追加:

```gdscript
	# --- 隐藏电话线：提示词与文案 ---
	_check(LLM.PHONE_EPILOGUE_PROMPT.length() > 0, "电话结局旁白提示词存在")
	_check(str(Content.ENDING_PHONE_FALLBACK).length() > 0, "电话结局兜底文案存在")
	_check(("电话" in LLM.SYSTEM_PROMPT) and ("打通" in LLM.SYSTEM_PROMPT), "人设含电话元素")
	_check(("电话" in LLM.FINALE_SYSTEM_PROMPT) and ("打通" in LLM.FINALE_SYSTEM_PROMPT), "终局人设含电话元素")
	var pe = LLM.phone_epilogue_request_body([{"role": "user", "content": "hi"}])
	var pep = JSON.parse_string(pe)
	_check(typeof(pep) == TYPE_DICTIONARY and pep.has("messages") and pep.has("model"), "电话epilogue请求体含model/messages")
	_check(LLM.parse_phone_epilogue("  电话接通了。  ") == "电话接通了。", "解析epilogue剥首尾空白")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL,`Invalid get index 'PHONE_EPILOGUE_PROMPT'` 等

- [ ] **Step 3a: SYSTEM_PROMPT 加电话块**

在 `game/llm.gd` 的 `SYSTEM_PROMPT` 里,把这段:

```gdscript
因为说着说着，你会记起来她已经不在了；但你很快把那记忆推走。

【说话规则】
```

替换为(中间插入电话块):

```gdscript
因为说着说着，你会记起来她已经不在了；但你很快把那记忆推走。

【关于电话（藏着，只在被直接问到时才提，平时绝不主动说）】
你天天给秀兰打电话。在你的认知里，电话总能打通，她在那头接、你们能说上几句。
只有被问到你为什么总打电话、给谁打电话时，你才平静地说：你给秀兰打，电话打得通，她会接。
被追问"你是怎么打通的"，你不解释原理，只笃定地说她就是接了——你会摸出手机，要拨给她看。

【说话规则】
```

- [ ] **Step 3b: FINALE_SYSTEM_PROMPT 加电话块**

在 `game/llm.gd` 的 `FINALE_SYSTEM_PROMPT` 里,把这段:

```gdscript
你只活在当下这一句的反应里。

【说话规则】
```

替换为:

```gdscript
你只活在当下这一句的反应里。

【关于电话（藏着，只在被直接问到时才提）】
你天天给秀兰打电话，在你的认知里电话总能打通、她会接。被问到你为什么总打电话、给谁打时，你才平静说你给秀兰打、打得通；被追问"怎么打通的"，你不解释，只笃定说她就是接了，会摸出手机要拨给她看。

【说话规则】
```

- [ ] **Step 3c: llm.gd 加 epilogue 提示词/构建/解析**

在 `game/llm.gd` 末尾(Task 1 的 `asks_how_connected` 之后)追加:

```gdscript
const PHONE_EPILOGUE_PROMPT := """你是一部叙事侦探游戏的结局旁白作者。老人周明远坚信能给亡妻林秀兰打电话、而且打得通；此刻他当着侦探的面，拨通了那个号码。
给你这场对话，请写这场"电话打通了"的结局旁白，只输出旁白正文（别的都不要）：
- 2-4 句，文学、克制、留白；诡异、发凉，但点到为止。
- 写"电话接通了"的那一刻与老人的神情；不要点破是谁接的、不要写"AI/合成语音"，把"谁在那头"完全留白。
- 绝不写任何格言、金句、点题句；绝不写血腥或自杀的具体画面。"""

static func build_phone_epilogue_messages(history: Array) -> Array:
	var transcript := ""
	for m in history:
		var who := "玩家" if str(m.get("role")) == "user" else "周明远"
		transcript += who + "：" + str(m.get("content")) + "\n"
	return [
		{"role": "system", "content": PHONE_EPILOGUE_PROMPT},
		{"role": "user", "content": "【对话记录】\n" + transcript + "\n写这场电话打通了的结局旁白，只输出正文。"},
	]

static func phone_epilogue_request_body(history: Array) -> String:
	return JSON.stringify({
		"model": MODEL,
		"messages": build_phone_epilogue_messages(history),
		"temperature": 0.7,
	})

# 取正文、剥首尾空白；空则返回 ""(调用方兜底 ENDING_PHONE_FALLBACK)。
static func parse_phone_epilogue(content: String) -> String:
	return str(content).strip_edges()
```

- [ ] **Step 3d: content.gd 加兜底文案**

在 `game/content.gd` 的 `ENDING_FALLBACK` 常量定义**之后**追加:

```gdscript
# 隐藏电话结局的兜底正文：AI 不可用时用。诡异、留白，不点破是谁接的。
const ENDING_PHONE_FALLBACK := "电话接通了。\n听筒里很静，又好像有谁，在很远的地方，轻轻应了一声。\n他笑了，把听筒贴得更紧。"
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS,6 条新断言全 ok,0 失败

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/llm.gd Game/client/game/content.gd Game/client/tests/run_tests.gd
git commit -m "feat(电话线): 老头电话人设(2处提示词) + PHONE_EPILOGUE_PROMPT/构建/解析 + ENDING_PHONE_FALLBACK"
```

---

### Task 3: 编排接线 — PhoneHttp 节点 + interrogation.gd 两步触发与结局

**Files:**
- Modify: `Game/client/scenes/interrogation.tscn`(加 PhoneHttp 节点)
- Modify: `Game/client/scenes/interrogation.gd`(@onready + _ready 连接 + _send 门控 + _trigger_phone_ending + _on_phone_epilogue)
- Modify: `Game/client/tests/test_interrogation_struct.gd`(加 PhoneHttp 断言)

**Interfaces:**
- Consumes: `LLM.asks_why_calls`/`asks_how_connected`/`phone_epilogue_request_body`/`parse_phone_epilogue`/`extract_content`/`CHAT_URL`/`headers`(Task 1-2)、`Content.ENDING_PHONE_FALLBACK`、`Game.state.phone_line_unlocked`、现有 `_trigger_ending_emergent`/`_show_player_bubble`/`_show_zhou_bubble`/`_pending_end`

- [ ] **Step 1: 先更新结构测试(会失败)**

在 `tests/test_interrogation_struct.gd` 第 6 行的节点列表里,把 `"TitleHttp"` 改成 `"TitleHttp", "PhoneHttp"`:

```gdscript
	for p in ["Evidence", "Evidence/VBox/Card_photo", "Evidence/VBox/Card_death", "Evidence/VBox/Card_farewell", "Evidence/VBox/Card_molog", "DirectorHttp", "EndSlide/VBox/TitleLabel", "EndSlide/VBox/EndButtons/BackToMenuBtn", "EndSlide/VBox/EndButtons/ViewAchieveBtn", "TitleHttp", "PhoneHttp"]:
```

- [ ] **Step 2: 跑结构测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_interrogation_struct.gd`
Expected: FAIL,`缺节点 PhoneHttp` + `interrogation 结构 FAIL`,退出码 1

- [ ] **Step 3a: interrogation.tscn 加 PhoneHttp 节点**

在 `interrogation.tscn` 的 `[node name="DirectorHttp" type="HTTPRequest" parent="."]` 那个节点块**之后**(它后面是空行再 `[node name="FadeOverlay"...]`),插入一行节点:

```
[node name="PhoneHttp" type="HTTPRequest" parent="."]
```

(即在 DirectorHttp 与 FadeOverlay 之间新增 PhoneHttp 节点。)

- [ ] **Step 3b: interrogation.gd 加 @onready 引用 + _ready 连接**

在 `interrogation.gd` 的 `@onready var title_http: HTTPRequest = $TitleHttp` 那行**之后**加:

```gdscript
@onready var phone_http: HTTPRequest = $PhoneHttp
```

在 `_ready()` 里 `title_http.timeout = 25.0` 那行**之后**加:

```gdscript
	phone_http.request_completed.connect(_on_phone_epilogue)
	phone_http.timeout = 14.0
```

- [ ] **Step 3c: interrogation.gd `_send` 里插入两步门控**

在 `_send()` 里,找到这段(空消息+证据兜底之后、出示证据结算 `for c in armed:` 之前):

```gdscript
	if msg == "" and not armed.is_empty():
		var names := []
		for c in armed: names.append(str(c["label"]))
		msg = "（你把%s推到他面前。）" % "、".join(names)
	for c in armed:
```

改为(中间插入门控):

```gdscript
	if msg == "" and not armed.is_empty():
		var names := []
		for c in armed: names.append(str(c["label"]))
		msg = "（你把%s推到他面前。）" % "、".join(names)
	# —— 隐藏电话线（在出示证据结算之前判定）——
	# 已解锁 + 问"怎么打通" → 直接进电话结局；否则若问起打电话 → 解锁，继续正常对话。
	if not finished and Game.state.phone_line_unlocked and LLM.asks_how_connected(msg):
		_trigger_phone_ending(msg)
		return
	if LLM.asks_why_calls(msg):
		state.phone_line_unlocked = true
	for c in armed:
```

- [ ] **Step 3d: interrogation.gd 加 `_trigger_phone_ending` + `_on_phone_epilogue`**

在 `interrogation.gd` 的 `_trigger_ending_emergent` 函数**之前**(即 `# 涌现结局入口：渐黑 ...` 注释那行之前)插入:

```gdscript
# 隐藏电话结局：玩家追问"怎么打通的" → 老头脚本化收尾台词 → AI 现写诡异 epilogue → 复用涌现结局。
func _trigger_phone_ending(msg: String) -> void:
	if finished: return
	_show_player_bubble(msg)
	state.add_to_history("user", msg)
	input.text = ""
	input.editable = false
	send_btn.disabled = true
	# 老头脚本化的瘆人收尾台词（固定，不走模型）
	var last_line := "你不信？……我拨给你看。（他摸出手机，按下那串号码，把听筒凑到你耳边）……你听。"
	_show_zhou_bubble(last_line)
	state.add_to_history("assistant", last_line)
	# 结局类型给称号用（_trigger_ending_emergent 会读 _pending_end.kind 发称号请求）
	_pending_end = {"end": true, "kind": "call", "epilogue": ""}
	# AI 现写 epilogue；发不出去就直接兜底进结局
	var err := phone_http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, LLM.phone_epilogue_request_body(state.history))
	if err != OK:
		_on_phone_epilogue(0, 0, PackedStringArray(), PackedByteArray())

func _on_phone_epilogue(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if finished: return
	var epi := ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0:
		var data = JSON.parse_string(body.get_string_from_utf8())
		epi = LLM.parse_phone_epilogue(LLM.extract_content(data))
	if epi == "":
		epi = Content.ENDING_PHONE_FALLBACK
	_pending_end["epilogue"] = epi
	_trigger_ending_emergent(epi)
```

- [ ] **Step 4: 跑结构测试 + 全套 + 场景冒烟确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_interrogation_struct.gd`
Expected: PASS,`interrogation 结构 OK`,退出码 0
Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS,0 失败
Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/interrogation.tscn --quit-after 4`
Expected: 干净退出,无 `SCRIPT ERROR` / `Node not found`

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/scenes/interrogation.tscn Game/client/scenes/interrogation.gd Game/client/tests/test_interrogation_struct.gd
git commit -m "feat(电话线): 两步门控接线 + _trigger_phone_ending(脚本台词→AI epilogue→复用涌现结局) + PhoneHttp 节点"
```

提交后**提醒用户**:编辑器开着 interrogation.tscn 需 **Reload Saved Scene**(新增 PhoneHttp 节点)。

---

### Task 4: 真模型实测 + 项目记忆

**Files:**
- Create(临时,可丢): `/tmp/phone_ending_probe.gd`
- Modify: `PROJECT_PROGRESS.md` / `PROJECT_TODO.md`

> 此任务**需要真 Moonshot key**。执行前向用户确认 key 已注入(设置里填或脚本里临时填)。

- [ ] **Step 1: 写探针脚本(验证 AI epilogue 真实输出)**

创建 `/tmp/phone_ending_probe.gd`:

```gdscript
extends SceneTree
const LLM = preload("res://game/llm.gd")
func _initialize() -> void:
	LLM.set_runtime_key("__在此粘贴真Moonshot key__")
	var history := [
		{"role": "user", "content": "你为什么老打电话？"},
		{"role": "assistant", "content": "我给秀兰打。电话打得通，她会接。"},
		{"role": "user", "content": "那你是怎么打通的？"},
		{"role": "assistant", "content": "你不信？……我拨给你看。你听。"},
	]
	var http := HTTPRequest.new()
	get_root().add_child(http)
	await process_frame
	http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, LLM.phone_epilogue_request_body(history))
	var r = await http.request_completed
	var content := LLM.extract_content(JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()))
	print("==== AI 电话结局 epilogue ====")
	print(LLM.parse_phone_epilogue(content))
	quit(0)
```

- [ ] **Step 2: 填真 key 并运行**

把脚本里 `__在此粘贴真Moonshot key__` 换成真 key,然后:
Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s /tmp/phone_ending_probe.gd`

- [ ] **Step 3: 人工核对(验收门槛)**

把输出贴给用户,核对 AI epilogue:① 诡异、留白、2-4 句;② **不点破是谁接的**、不写"AI/合成语音";③ 不写金句格言、不写血腥/自杀具体画面。不符 → 回 Task 2 调 `PHONE_EPILOGUE_PROMPT` 重测。

> 完整的实机两步触发(问电话→问怎么打通→老头台词→渐黑→AI结局+称号)由用户 F5 走一遍确认(需填 key)。

- [ ] **Step 4: 清理临时脚本**

```bash
rm -f /tmp/phone_ending_probe.gd
```

- [ ] **Step 5: 更新项目记忆并提交**

更新 `PROJECT_PROGRESS.md`(最近进展加"隐藏电话结局线落地")、`PROJECT_TODO.md`(标完成;原 §十三 延后项更新为"已做简化版,音频/合成语音谜底仍未做")。

```bash
cd /Users/xulei/.dev/Distortion
git add PROJECT_PROGRESS.md PROJECT_TODO.md
git commit -m "docs(memory): 记录隐藏电话结局线落地"
```

---

## Self-Review

**Spec coverage(逐节对照):**
- 随时可触发(不需 molog)→ Task 3 `_send` 门控不依赖 in_finale ✓
- 两步触发 + 未解锁不触发 → Task 1 检测 + flag,Task 3 门控顺序(先判触发再判解锁)✓
- 老头电话人设(只被问到才提)→ Task 2 两处提示词电话块 ✓
- 脚本化收尾台词 → Task 3 `_trigger_phone_ending` last_line ✓
- AI 现写诡异 epilogue + 兜底 → Task 2 PHONE_EPILOGUE_PROMPT/parse + ENDING_PHONE_FALLBACK,Task 3 `_on_phone_epilogue` ✓
- 复用渐黑/称号/结局画面 → Task 3 `_trigger_ending_emergent(epi)` + `_pending_end.kind="call"` ✓
- 无音频/不揭破 → 提示词与文案约束(Task 2)✓
- 单测(检测/门控/兜底/提示词/节点)→ Task 1 + Task 2 + Task 3 结构测试 ✓
- 真 key 实测 → Task 4 ✓

**Placeholder 扫描:** 无 TBD/TODO;所有步骤含完整代码与命令。Task 4 的 key 占位是运行时输入项,已标注需用户提供。

**类型一致性:** `asks_why_calls`/`asks_how_connected`(→bool)、`phone_line_unlocked`(bool)、`PHONE_EPILOGUE_PROMPT`/`phone_epilogue_request_body`/`parse_phone_epilogue`、`ENDING_PHONE_FALLBACK`、`_trigger_phone_ending`/`_on_phone_epilogue`、节点 `PhoneHttp`(tscn/gd @onready/结构测试三处一致)、`_pending_end` 的 `kind="call"` 与 `_trigger_ending_emergent` 读取一致。
