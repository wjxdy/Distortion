# 终端机自然语言查询机 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把警局终端机从"点按钮全文摊开"改成"打字提问、一问一答、聊天历史可回看"的自然语言查询机，模型只检索不创作，离线/无 key 有本地兜底。

**Architecture:** 模型当检索员——给它"档案清单（id+标签+关键词）+玩家这句问"，它只回一个档案 id（或 NONE）；客户端拿 id 去 `TERMINAL_FILES[id].text` 取写死原文显示。模型失败/超时/401 时用同一套关键词在本地 `terminal_local_match` 兜底。复用审讯室那条成熟的 `HTTPRequest`+重试链路。

**Tech Stack:** Godot 4 (GDScript)、客户端直连 Moonshot/Kimi（OpenAI 兼容）、headless `run_tests.gd` 做确定性单测。

## Global Constraints

- **不改剧情/不改文案**：知识库就用现有 `TERMINAL_FILES` 5 条，正文 `text`/`grants_key`/`label` 一字不动，只加 `keywords` 检索元数据。
- **零幻觉铁律**：模型只输出档案 id 或 NONE，绝不输出正文；玩家看到的永远是写死的 `text` 原文。
- **永不卡死**：模型失败/超时/占位符 401 → 转本地 `terminal_local_match` 兜底；终端离线也能玩通。
- **项目铁律（CLAUDE.md）**：摆着的控件（LineEdit/Button/RichTextLabel）进 `.tscn` 当真实可拖节点；脚本只管逻辑。改 `.tscn` 后提醒用户在编辑器 **Reload Saved Scene**。
- **保留**：`SubmitPhoneBtn`（📱 接入手机·恢复历史日志）+ 整个 `LogView` 莫忘蒙太奇面板 + `BackBtn` —— 原样不动，是另一条线。
- **检索语义**：单条独立检索，每次只喂【档案清单+这一句问】，不喂聊天历史。
- **测试命令**（全文统一用此变量）：
  `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`
  确定性单测：`"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`（退出码 0=全过，1=有失败）
- **API key**：仓库内置 `REPLACE_WITH_KIMI_API_KEY` 占位符；真模型实测需在脚本/设置里填真 Moonshot key，否则 401。

---

### Task 1: content.gd — 给 TERMINAL_FILES 加 keywords

**Files:**
- Modify: `Game/client/game/content.gd:128-154`（`TERMINAL_FILES` 字典）
- Test: `Game/client/tests/run_tests.gd`（加断言）

**Interfaces:**
- Produces: `Content.TERMINAL_FILES[id]["keywords"]: Array[String]`（5 个 id：case/zhou/address/wife/medical 各有非空 keywords）。`text`/`grants_key`/`label` 保持不变。

- [ ] **Step 1: 写失败断言**

在 `tests/run_tests.gd` 第 73-74 行那段终端断言后面（`for fid in Content.TERMINAL_FILES:` 循环之后）追加：

```gdscript
	# --- 终端查询：每条案卷都有检索关键词（新查询机用） ---
	for fid in Content.TERMINAL_FILES:
		_check(Content.TERMINAL_FILES[fid].has("keywords") and (Content.TERMINAL_FILES[fid]["keywords"] is Array) and not Content.TERMINAL_FILES[fid]["keywords"].is_empty(), "终端案卷有检索关键词: " + str(fid))
	_check("住哪" in Content.TERMINAL_FILES["address"]["keywords"], "住址案卷含'住哪'关键词")
	_check("老婆" in Content.TERMINAL_FILES["wife"]["keywords"], "林秀兰案卷含'老婆'关键词")
	_check("安葬" in Content.TERMINAL_FILES["medical"]["keywords"], "安葬案卷含'安葬'关键词")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL，出现 `FAIL 终端案卷有检索关键词: case`（keywords 字段还不存在）

- [ ] **Step 3: 给每条案卷加 keywords**

把 `content.gd` 的 `TERMINAL_FILES` 改成（仅加 `keywords` 行，其余原样）：

```gdscript
const TERMINAL_FILES := {
	"case": {
		"label": "报案记录",
		"grants_key": "",
		"keywords": ["案件", "案子", "报案", "案情", "怎么回事", "发生了什么", "为什么来", "概要"],
		"text": "报案记录 #DC-0617：周明远，78 岁，独居。近一年几乎每天来报案，称妻子林秀兰'走丢了''出门一直没回来'，恳请协查。每一次，他都像第一次来报案。"
	},
	"zhou": {
		"label": "周明远 资料",
		"grants_key": "",
		"keywords": ["周明远", "老头", "老人", "这个人", "他是谁", "什么人", "资料", "背景", "他"],
		"text": "周明远，退休工人，无前科。近一年频繁来局报案，称妻子走丢。社区备注：疑似阿尔茨海默，独居，无子女在侧。"
	},
	"address": {
		"label": "周明远 户籍 / 住址",
		"grants_key": "home_address",
		"keywords": ["住址", "地址", "家", "住哪", "住在哪", "家在哪", "户籍", "小区", "哪里住", "房子"],
		"text": "户籍登记：周明远，独居。现住址——晚晴小区 2 号楼 702 室。（知道他家在哪了。）"
	},
	"wife": {
		"label": "林秀兰 记录",
		"grants_key": "linxiulan",
		"keywords": ["林秀兰", "妻子", "老婆", "老伴", "他妻子", "夫人", "媳妇", "走丢", "失踪", "她去哪", "死", "去世"],
		"text": "死亡登记：林秀兰，周明远之妻。长期重病（慢性肺病晚期）。三年前于家中安详离世。死亡证明：自然死亡。——她不是走丢了，是早就去世了。"
	},
	"medical": {
		"label": "林秀兰 安葬记录",
		"grants_key": "farewell",
		"keywords": ["安葬", "殡葬", "下葬", "骨灰", "墓", "安和园", "葬在哪", "埋", "葬礼", "墓地"],
		"text": "殡葬登记：林秀兰，骨灰安放于安和园。经办人：其夫 周明远。——是他，亲手送的她。"
	}
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS，无 FAIL，末行 `结果: N 通过, 0 失败`

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/content.gd Game/client/tests/run_tests.gd
git commit -m "feat(terminal): TERMINAL_FILES 每条加 keywords 检索元数据(正文不动)"
```

---

### Task 2: llm.gd — terminal_local_match（本地关键词兜底）

**Files:**
- Modify: `Game/client/game/llm.gd`（在 `parse_director` 后、文件末尾追加）
- Test: `Game/client/tests/run_tests.gd`

**Interfaces:**
- Consumes: `Content.TERMINAL_FILES[id]["keywords"]`（Task 1）
- Produces: `LLM.terminal_local_match(query: String) -> String` —— 返回首个 keywords 命中的档案 id；无命中返回 `""`。静态方法。

- [ ] **Step 1: 写失败测试**

在 `tests/run_tests.gd` 的 LLM 区块（约 224 行 fail_reason 断言之后）追加：

```gdscript
	# --- 终端查询：本地关键词兜底匹配 LLM.terminal_local_match ---
	_check(LLM.terminal_local_match("他住哪") == "address", "本地匹配: 他住哪→address")
	_check(LLM.terminal_local_match("他老婆呢") == "wife", "本地匹配: 他老婆→wife")
	_check(LLM.terminal_local_match("安葬在哪里") == "medical", "本地匹配: 安葬→medical")
	_check(LLM.terminal_local_match("周明远是谁") == "zhou", "本地匹配: 周明远→zhou")
	_check(LLM.terminal_local_match("今天天气怎么样") == "", "本地匹配: 无关问题→空")
	_check(LLM.terminal_local_match("") == "", "本地匹配: 空输入→空")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL，`Invalid call. Nonexistent function 'terminal_local_match'`（或编译错误）

- [ ] **Step 3: 实现 terminal_local_match**

在 `llm.gd` 末尾（`parse_reply` 之后）追加。注意 `llm.gd` 顶部尚未 preload Content，需在文件顶部 `const ... =` 区或方法内 preload；这里用方法内 `preload` 避免循环依赖：

```gdscript
# —— 终端查询机：本地关键词兜底（模型不可用时用，确定性、可单测）——
# 把玩家这句问与各案卷 keywords 做子串包含匹配，返回首个命中的档案 id；无命中返回 ""。
static func terminal_local_match(query: String) -> String:
	var q := query.strip_edges()
	if q == "":
		return ""
	var files = preload("res://game/content.gd").TERMINAL_FILES
	for fid in files:
		var kws = files[fid].get("keywords", [])
		for kw in kws:
			if str(kw) != "" and q.find(str(kw)) >= 0:
				return str(fid)
	return ""
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS，6 条本地匹配断言全 ok，0 失败

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/llm.gd Game/client/tests/run_tests.gd
git commit -m "feat(terminal): LLM.terminal_local_match 本地关键词兜底匹配"
```

---

### Task 3: llm.gd — parse_terminal_result（从模型输出抠 id）

**Files:**
- Modify: `Game/client/game/llm.gd`（terminal_local_match 之后追加）
- Test: `Game/client/tests/run_tests.gd`

**Interfaces:**
- Produces: `LLM.parse_terminal_result(content: String) -> String` —— 从模型输出里抠出**合法档案 id**（必须存在于 `TERMINAL_FILES`）；找不到合法 id（含 NONE/空/乱答）返回 `""`。静态方法。

- [ ] **Step 1: 写失败测试**

在 `tests/run_tests.gd` 接着 Task 2 的断言后追加：

```gdscript
	# --- 终端查询：从模型输出抠合法 id LLM.parse_terminal_result ---
	_check(LLM.parse_terminal_result("zhou") == "zhou", "解析: 裸 id")
	_check(LLM.parse_terminal_result("[wife]") == "wife", "解析: 方括号 id")
	_check(LLM.parse_terminal_result("id: address") == "address", "解析: 带前缀 id")
	_check(LLM.parse_terminal_result("应该是 medical 这条") == "medical", "解析: 句中 id")
	_check(LLM.parse_terminal_result("NONE") == "", "解析: NONE→空")
	_check(LLM.parse_terminal_result("没有匹配的记录") == "", "解析: 自然语言无→空")
	_check(LLM.parse_terminal_result("xyz") == "", "解析: 非法 id→空")
	_check(LLM.parse_terminal_result("") == "", "解析: 空→空")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL，`Nonexistent function 'parse_terminal_result'`

- [ ] **Step 3: 实现 parse_terminal_result**

在 `llm.gd` 的 `terminal_local_match` 之后追加（用正则抠出小写字母词，逐个比对是否是合法档案 id）：

```gdscript
# 从模型输出里抠出合法档案 id（必须在 TERMINAL_FILES 里）；抠不到/NONE/乱答→""。
static func parse_terminal_result(content: String) -> String:
	var files = preload("res://game/content.gd").TERMINAL_FILES
	var text := str(content)
	var re := RegEx.new()
	re.compile("[A-Za-z_]+")
	for m in re.search_all(text):
		var w := m.get_string(0).to_lower()
		if files.has(w):
			return w
	return ""
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS，8 条解析断言全 ok，0 失败

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/llm.gd Game/client/tests/run_tests.gd
git commit -m "feat(terminal): LLM.parse_terminal_result 从模型输出抠合法档案id"
```

---

### Task 4: llm.gd — TERMINAL_SYSTEM_PROMPT + 请求构建

**Files:**
- Modify: `Game/client/game/llm.gd`（parse_terminal_result 之后追加）
- Test: `Game/client/tests/run_tests.gd`

**Interfaces:**
- Consumes: `Content.TERMINAL_FILES`（id/label/keywords）
- Produces:
  - `LLM.TERMINAL_SYSTEM_PROMPT: String`
  - `LLM.build_terminal_messages(query: String) -> Array` —— 返回 `[{role:"system", content: 提示+档案清单}, {role:"user", content: query}]`
  - `LLM.terminal_request_body(query: String) -> String` —— JSON 请求体，低温度 0.1

- [ ] **Step 1: 写失败测试**

在 `tests/run_tests.gd` 接着 Task 3 的断言后追加：

```gdscript
	# --- 终端查询：检索员提示词与请求构建 ---
	_check(LLM.TERMINAL_SYSTEM_PROMPT.length() > 0, "终端检索员提示词存在")
	_check(("NONE" in LLM.TERMINAL_SYSTEM_PROMPT), "提示词要求无匹配时回 NONE")
	var tmsgs = LLM.build_terminal_messages("他住哪")
	_check(tmsgs.size() == 2 and tmsgs[0]["role"] == "system" and tmsgs[1]["role"] == "user", "终端messages=system+user")
	_check(tmsgs[1]["content"] == "他住哪", "终端user消息=玩家原句")
	_check(("address" in tmsgs[0]["content"]) and ("zhou" in tmsgs[0]["content"]), "系统消息含档案id清单")
	var tbody = LLM.terminal_request_body("他住哪")
	var tparsed = JSON.parse_string(tbody)
	_check(typeof(tparsed) == TYPE_DICTIONARY and tparsed.has("messages") and tparsed.has("model"), "终端请求体含 model/messages")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL，`Invalid get index 'TERMINAL_SYSTEM_PROMPT'` 或 `Nonexistent function`

- [ ] **Step 3: 实现提示词与请求构建**

在 `llm.gd` 的 `parse_terminal_result` 之后追加：

```gdscript
const TERMINAL_SYSTEM_PROMPT := """你是一台警局综合查询终端的检索程序。你只做一件事：根据用户的查询，从下面这份【档案清单】里找出最匹配的【一条】档案，然后只输出它的 id。

【档案清单】会在用户消息前由系统给出，每条形如：id | 标签 | 关键词。
【输出规则·必须严格遵守】
- 只输出那一条档案的 id（如 zhou），不要输出任何别的字、解释、标点、正文内容。
- 绝对不要复述、编造或猜测档案的内容；你看不到正文，也不准编造正文。
- 如果没有任何一条档案匹配用户的查询，只输出：NONE
- 永远只输出一个 id 或 NONE，不要输出多个。"""

# 拼档案清单（只给 id/标签/关键词，绝不给正文 text），供模型当检索目录。
static func _terminal_catalog() -> String:
	var files = preload("res://game/content.gd").TERMINAL_FILES
	var lines: Array = []
	for fid in files:
		var label = str(files[fid].get("label", ""))
		var kws = files[fid].get("keywords", [])
		lines.append("%s | %s | %s" % [fid, label, ", ".join(PackedStringArray(kws))])
	return "【档案清单】\n" + "\n".join(lines)

static func build_terminal_messages(query: String) -> Array:
	var sys := TERMINAL_SYSTEM_PROMPT + "\n\n" + _terminal_catalog()
	return [
		{"role": "system", "content": sys},
		{"role": "user", "content": query},
	]

static func terminal_request_body(query: String) -> String:
	return JSON.stringify({
		"model": MODEL,
		"messages": build_terminal_messages(query),
		"temperature": 0.1,
	})
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS，终端提示词/构建断言全 ok，0 失败

- [ ] **Step 5: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/game/llm.gd Game/client/tests/run_tests.gd
git commit -m "feat(terminal): TERMINAL_SYSTEM_PROMPT + build_terminal_messages + terminal_request_body"
```

---

### Task 5: terminal.tscn — UI 改造（删文件夹按钮，加聊天查询 UI）

**Files:**
- Modify: `Game/client/scenes/terminal.tscn`（删 FileList 下 5 个案卷按钮；改右侧显示区为聊天 RichTextLabel；加底部 LineEdit+查询 Button）
- Modify: `Game/client/tests/test_terminal_room.gd`（更新节点断言）

**Interfaces:**
- Produces 场景新节点（terminal.gd 将 `@onready` 引用）：
  - `TerminalUI/Chat`（RichTextLabel，bbcode_enabled、scroll_active、fit_content 关）—— 聊天历史区
  - `TerminalUI/QueryInput`（LineEdit）—— 输入框
  - `TerminalUI/QueryBtn`（Button，text="查询"）—— 发送按钮
- 保留：`TerminalUI/BackBtn`、`TerminalUI/FileList/SubmitPhoneBtn`、`TerminalUI/LogView`（及其子节点）、`TerminalUI/Header`、`Dim`、`Panel`

> **注意**：本任务改 `.tscn`，无法用 TDD 红绿，靠场景加载测试 + 更新 test_terminal_room.gd 验证节点存在。

- [ ] **Step 1: 更新 test_terminal_room.gd 断言（先写，会失败）**

把 `tests/test_terminal_room.gd` 第 25-26 行那段 TerminalUI 断言替换/扩充为：

```gdscript
			if root.has_node("TerminalUI"):
				_check(not root.get_node("TerminalUI").visible, "TerminalUI 默认隐藏")
				_check(root.has_node("TerminalUI/Chat"), "终端有聊天记录区 Chat")
				_check(root.has_node("TerminalUI/QueryInput"), "终端有查询输入框 QueryInput")
				_check(root.has_node("TerminalUI/QueryBtn"), "终端有查询按钮 QueryBtn")
				_check(root.has_node("TerminalUI/BackBtn"), "终端保留关闭按钮")
				_check(root.has_node("TerminalUI/FileList/SubmitPhoneBtn"), "终端保留接入手机按钮")
				_check(root.has_node("TerminalUI/LogView"), "终端保留莫忘日志面板")
				_check(not root.has_node("TerminalUI/FileList/CaseBtn"), "旧案卷按钮已移除")
```

- [ ] **Step 2: 跑场景测试确认失败**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_terminal_room.gd`
Expected: FAIL，`FAIL 终端有聊天记录区 Chat`（节点还没建）

- [ ] **Step 3: 改 terminal.tscn —— 删 5 个案卷按钮**

删除 `terminal.tscn` 中这 5 个节点块（保留 `FileList` 容器本身和 `SubmitPhoneBtn`）：
`[node name="CaseBtn" ...]`、`ZhouBtn`、`AddressBtn`、`WifeBtn`、`MedicalBtn`（第 144-172 行整段五个 button 节点）。

- [ ] **Step 4: 改 terminal.tscn —— 右侧显示区改成聊天 RichTextLabel**

把 `DisplayBg` 下的 `Display`（Label，189-203 行）整个节点替换为 RichTextLabel（节点名改 `Chat`，仍挂在 `DisplayBg` 下，但 terminal.gd 用 `TerminalUI/Chat` 引用——为简化路径，直接把 Chat 挂在 TerminalUI 下）。具体：删掉 `DisplayBg` 的 `Display` 子节点，新增：

```
[node name="Chat" type="RichTextLabel" parent="TerminalUI"]
layout_mode = 0
offset_left = 384.0
offset_top = 96.0
offset_right = 1240.0
offset_bottom = 612.0
bbcode_enabled = true
scroll_active = true
scroll_following = true
theme_override_colors/default_color = Color(0.75, 0.92, 0.8, 1)
theme_override_font_sizes/normal_font_size = 20
text = "▍综合查询终端　输入要查的人或事，回车检索。"
```

（`DisplayBg` ColorRect 可保留作背景，或删除；保留更省事，把它的 offset_bottom 改到 612 与 Chat 对齐即可。）

- [ ] **Step 5: 改 terminal.tscn —— 底部加输入框 + 查询按钮**

在 `TerminalUI` 下新增两个节点：

```
[node name="QueryInput" type="LineEdit" parent="TerminalUI"]
layout_mode = 0
offset_left = 384.0
offset_top = 624.0
offset_right = 1090.0
offset_bottom = 672.0
theme_override_font_sizes/font_size = 20
placeholder_text = "输入要查询的内容，回车发送…"

[node name="QueryBtn" type="Button" parent="TerminalUI"]
layout_mode = 0
offset_left = 1104.0
offset_top = 624.0
offset_right = 1240.0
offset_bottom = 672.0
theme_override_font_sizes/font_size = 20
text = "查询"
```

- [ ] **Step 6: 跑场景测试 + 全套测试确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_terminal_room.gd`
Expected: PASS，新节点断言全 ok

> 注：此时 `terminal.gd` 还引用着已删的 5 个按钮（`_ready` 里 connect CaseBtn 等），**场景实例化会报错**。所以本步骤的"PASS"以 Task 6 改完 terminal.gd 后为准；若本步骤实例化即报 `Node not found: CaseBtn`，属预期，下一任务修复。**先继续 Task 6，不在此卡住。**

- [ ] **Step 7: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/scenes/terminal.tscn Game/client/tests/test_terminal_room.gd
git commit -m "feat(terminal): UI改造-删案卷按钮+加聊天查询区/输入框/查询按钮(保留手机接入与日志面板)"
```

提交后**提醒用户**：编辑器若开着 terminal.tscn，需 **Reload Saved Scene**。

---

### Task 6: terminal.gd — 接线查询流程

**Files:**
- Modify: `Game/client/scenes/terminal.gd`（删旧案卷按钮 connect 与 `_show`，加查询发送/解析/兜底/聊天渲染）
- Test: `Game/client/tests/run_tests.gd` + 场景加载测试

**Interfaces:**
- Consumes: `LLM.terminal_request_body` / `parse_terminal_result` / `terminal_local_match`（Task 2-4）、`LLM.headers()` / `LLM.CHAT_URL` / `LLM.fail_reason`、`Content.TERMINAL_FILES`、`Content.MOWANG_HINTS`、`FILE_HINTS`、`Game.state.add_key` / `fire_hint`
- Produces: `terminal.gd` 内 `_grant_and_hint(id)` 抽出旧 `_show` 副作用；查询走 HTTPRequest 回调，失败转本地兜底。

- [ ] **Step 1: 删旧引用 + 加 HTTPRequest 节点引用与成员**

改 `terminal.gd`：
1. 删第 20 行 `@onready var display: Label = $TerminalUI/DisplayBg/Display`，改为：
```gdscript
@onready var chat: RichTextLabel = $TerminalUI/Chat
@onready var query_input: LineEdit = $TerminalUI/QueryInput
@onready var query_btn: Button = $TerminalUI/QueryBtn
```
2. 删 `_ready` 里第 37-41 行那 5 行 `($TerminalUI/FileList/CaseBtn ...).pressed.connect(_show.bind(...))`。
3. 删整个 `_show(file_id)` 函数（102-115 行）。
4. `_submit_phone` 里 `display.text = ...`（122 行）改成往聊天区追加：`_append("终端", "接入成功。本地只剩今天的对话，正在从云端恢复……\n✅ 已恢复全部历史日志。")`（`_append` 见 Step 3）。

- [ ] **Step 2: 加 HTTPRequest 节点（脚本动态创建——它是逻辑节点非 UI 控件，符合铁律）**

在 `terminal.gd` 顶部成员区加：
```gdscript
var _http: HTTPRequest
var _querying := false
```
在 `_ready()` 开头（`Music.play_police_ambience()` 后）加：
```gdscript
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 14.0
	_http.request_completed.connect(_on_query_reply)
	query_btn.pressed.connect(_on_query_submit)
	query_input.text_submitted.connect(func(_t: String) -> void: _on_query_submit())
```

- [ ] **Step 3: 加聊天渲染 + 查询发送 + 回调 + 副作用**

在 `terminal.gd` 末尾（`_go` 之前）追加：

```gdscript
# —— 自然语言查询：聊天渲染 ——
func _append(who: String, msg: String) -> void:
	var color := "9ad6a0" if who == "终端" else "cfe6ff"
	chat.append_text("\n[color=#%s]%s：[/color]%s\n" % [color, who, msg])

func _on_query_submit() -> void:
	if _querying:
		return
	var q := query_input.text.strip_edges()
	if q == "":
		return
	query_input.text = ""
	_append("你", q)
	_querying = true
	query_btn.disabled = true
	chat.append_text("\n[color=#6f8f78]检索中…[/color]\n")
	var err := _http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, LLM.terminal_request_body(q))
	_pending_query = q
	if err != OK:
		_resolve_query(LLM.terminal_local_match(q))

var _pending_query := ""

func _on_query_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var id := ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		id = LLM.parse_terminal_result(LLM.extract_content(data))
	else:
		# 模型失败/超时/401 → 本地关键词兜底，永不卡死
		id = LLM.terminal_local_match(_pending_query)
	_resolve_query(id)

func _resolve_query(id: String) -> void:
	_querying = false
	query_btn.disabled = false
	if id != "" and Content.TERMINAL_FILES.has(id):
		_append("终端", str(Content.TERMINAL_FILES[id]["text"]))
		_grant_and_hint(id)
	else:
		_append("终端", "无匹配记录。换个说法试试，或查某个人 / 某条记录。")

# 旧 _show 的副作用：查到带 grants_key 的档案 → 发钥匙 + 触发回审讯室提醒（去重）
func _grant_and_hint(id: String) -> void:
	var f = Content.TERMINAL_FILES.get(id)
	if f == null:
		return
	var k := str(f.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)
	if FILE_HINTS.has(id):
		var hid: String = FILE_HINTS[id]
		if Content.MOWANG_HINTS.has(hid) and Game.state.fire_hint(hid, str(Content.MOWANG_HINTS[hid])):
			phone.notify_hint()
```

- [ ] **Step 4: 跑全套测试 + 场景加载确认通过**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: PASS，0 失败
Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/test_terminal_room.gd`
Expected: PASS，0 失败（场景能实例化、新节点齐、无 `CaseBtn not found` 报错）

- [ ] **Step 5: 场景冒烟加载（无报错）**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/terminal.tscn --quit-after 4`
Expected: 干净退出，无 `SCRIPT ERROR` / `Node not found`

- [ ] **Step 6: 提交**

```bash
cd /Users/xulei/.dev/Distortion
git add Game/client/scenes/terminal.gd
git commit -m "feat(terminal): 接线自然语言查询(发送/解析/本地兜底/聊天渲染),保留发钥匙+提醒副作用"
```

---

### Task 7: 真模型实测（用户硬要求 —— 验证大模型符合预期）

**Files:**
- Create（临时，可丢）: `/tmp/terminal_query_probe.gd`
- 不进 git。

**Interfaces:** 复用 `LLM.terminal_request_body` / `parse_terminal_result`，用真 key 打真实请求。

> 此任务**需要真 Moonshot key**。执行前向用户索取/确认 key 已注入（设置里填或脚本里临时填）。仓库占位符会 401，那样只能验证"401→本地兜底"路径，无法验证模型真实检索行为。

- [ ] **Step 1: 写探针脚本**

创建 `/tmp/terminal_query_probe.gd`（SceneTree 脚本，逐条发真实查询、打印 模型原始输出 + 抠出的 id）：

```gdscript
extends SceneTree
const LLM = preload("res://game/llm.gd")
const Content = preload("res://game/content.gd")

func _initialize() -> void:
	LLM.set_runtime_key("__在此粘贴真Moonshot key__")
	var cases := ["周明远是谁", "他住在哪", "他老婆呢", "她安葬在哪", "案件是怎么回事", "今天天气如何", "附近有什么好吃的"]
	for q in cases:
		await _probe(q)
	quit(0)

func _probe(q: String) -> void:
	var http := HTTPRequest.new()
	get_root().add_child(http)
	http.request(LLM.CHAT_URL, LLM.headers(), HTTPClient.METHOD_POST, LLM.terminal_request_body(q))
	var r = await http.request_completed
	var content := LLM.extract_content(JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()))
	var id := LLM.parse_terminal_result(content)
	print("查询: %-14s | 模型原始输出: %-12s | 抠出id: %s | 期望命中: %s" % [q, content.replace("\n"," "), id, (id != "")])
	http.queue_free()
```

- [ ] **Step 2: 填入真 key 并运行**

Run: `"$GODOT" --headless --path /Users/xulei/.dev/Distortion/Game/client -s /tmp/terminal_query_probe.gd`
（先把脚本里 `__在此粘贴真Moonshot key__` 换成真 key）

- [ ] **Step 3: 人工核对三类预期（验收门槛）**

把上一步**完整输出贴给用户**，逐条核对：
- 有的（周明远/住哪/老婆/安葬/案件）→ 各自抠出正确 id（zhou/address/wife/medical/case），且终端实际会显示对应**写死原文**（原文不变可在游戏内或对照 content.gd 确认）。
- 没有的（天气/好吃的）→ 模型回 NONE，抠出 id 为空。
- 模型**没有**编造清单外的新 id、没有把正文吐出来。

三类都符合 → 机制通过。任一类异常（如模型老吐正文、或把"天气"误判成某档案）→ 回 Task 4 调 `TERMINAL_SYSTEM_PROMPT`，重测。

- [ ] **Step 4: 清理临时脚本**

```bash
rm -f /tmp/terminal_query_probe.gd
```

- [ ] **Step 5: 更新项目记忆并提交**

更新 `PROJECT_PROGRESS.md`（关键决策加"终端机改自然语言查询机：模型只检索+本地兜底+聊天历史"）、`PROJECT_TODO.md`（终端查询机标完成；记录手机解锁解谜/蓝裙子/电话结局为后续）。

```bash
cd /Users/xulei/.dev/Distortion
git add PROJECT_PROGRESS.md PROJECT_TODO.md
git commit -m "docs(memory): 记录终端机自然语言查询机落地"
```

---

## Self-Review

**Spec coverage（逐节对照）：**
- 模型只检索不创作 → Task 3/4（只回 id，客户端取原文）✓
- 本地兜底永不卡死 → Task 2 + Task 6 失败转 `terminal_local_match` ✓
- 聊天历史可回看 → Task 5 RichTextLabel + Task 6 `_append` 累积 ✓
- 单条独立检索（不喂历史）→ Task 4 `build_terminal_messages(query)` 只含单句 ✓
- 知识库正文不动只加 keywords → Task 1 ✓
- 删 5 按钮、保留 SubmitPhoneBtn/LogView/BackBtn → Task 5 ✓
- 发钥匙+FILE_HINTS 副作用保留 → Task 6 `_grant_and_hint` ✓
- 确定性单测 → Task 1-4 进 run_tests.gd；节点断言 → Task 5 test_terminal_room.gd ✓
- 真模型实测三类 → Task 7 ✓
- 错误处理（重试/401/空输入/非法id）→ Task 6（timeout 14s、失败兜底、空输入 return）+ Task 3（非法id→空）✓

**Placeholder 扫描：** 无 TBD/TODO；所有步骤含具体代码与命令。Task 7 的 key 占位是真实运行时输入项，已标注需用户提供。

**类型一致性：** `terminal_local_match`/`parse_terminal_result`/`build_terminal_messages`/`terminal_request_body`/`TERMINAL_SYSTEM_PROMPT`/`_grant_and_hint`/`_append` 在定义与调用处命名一致；节点名 `Chat`/`QueryInput`/`QueryBtn` 在 tscn(Task5)、gd 引用(Task6)、测试断言(Task5) 三处一致。

**已知衔接点：** Task 5 改完 tscn 但 terminal.gd 仍引用旧按钮 → 场景实例化报错，已在 Task 5 Step 6 注明"先继续 Task 6 修复"，Task 6 删除旧引用后场景恢复可加载。两个任务应连续执行、合并验证。
