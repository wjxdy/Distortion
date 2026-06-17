# 终局对峙 + 三分支结局 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把《失真》去邪教版的最后一块落地——手机取证链、莫忘日志跳切蒙太奇、终局对峙与三分支结局（A 戳破 / B 顺着他 / C 沉默离开）。

**Architecture:** 复用现有 `[[...]]` 隐藏标签机制：模型在终局吐 `[[end:xxx]]`，后端 `parseReply` 抽出经 `/chat` 透传，客户端据此触发渐黑→幻灯片结局。终局的"演法"靠客户端把发给模型的系统旁白从"调查进展"换成 `FINALE_NARRATION`（注入式，不动后端路由）。静态 UI 节点全部进 `.tscn`（Vibe Coding 可拖），脚本只做逻辑/动画。

**Tech Stack:** Godot 4.6（GDScript，客户端 `Game/client`）+ Node.js（后端 `Game/server`，`node:test`）。

## Global Constraints

- 静态结构（按钮/面板/标签/遮罩/幻灯片）**必须进 `.tscn` 作为真实节点**，脚本只做逻辑/动画/填字。禁止脚本 `XxxNode.new()+add_child()` 造本应摆界面的控件（`_banner` 等既有动态横幅除外）。
- 改 `.tscn`/`project.godot` 后**提醒用户 Reload Current Project（不保存）**。
- 字体 Zpix 全局默认；无美术处用色块 `ColorRect`+文字占位。
- 后端测试：`cd Game/server && node --test`（现 19 通过）。客户端逻辑测试：`"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`（现 52 通过，退出码 0=全过）。
- 场景加载自验：`"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/<场景>.tscn --quit-after 5`，看 stderr 无 SCRIPT ERROR/Compile（退出时常规 ObjectDB/resource 泄漏告警可忽略）。
- `[[end:xxx]]` 合法值仅四个：`ready` / `reveal` / `comfort` / `leave`。
- 分支判定：A=`reveal`、B=`comfort` 由模型从玩家发言判定；C=`leave` 由对峙界面「起身离开」按钮直接触发（玩家打字打不出沉默）。
- 三分支结局统一收尾字幕（写死）：`记忆，是我们选择记住的版本。`

---

### Task 0: 建分支 + 提交既有改动

**Files:**
- Modify: 无（仅 git 操作）

- [ ] **Step 1: 建终局 feature 分支**

```bash
cd /Users/xulei/.dev/Distortion
git checkout -b feat/final-confrontation-ending
```

- [ ] **Step 2: 单独提交"去小区提醒时机" bugfix（只这两个文件，别带用户未提交的 tscn/tail.gd）**

```bash
git add Game/client/scenes/interrogation.gd Game/server/src/oldman.js
git commit -m "fix(guide): 去小区提醒收紧为'查过死因+当面质问AI仍咬定'才弹,修提醒过早"
```

- [ ] **Step 3: 提交设计文档与本计划**

```bash
git add docs/superpowers/specs/2026-06-17-final-confrontation-ending-design.md docs/superpowers/plans/2026-06-17-final-confrontation-ending.md
git commit -m "docs(spec): 终局对峙+三分支结局 设计文档与实现计划"
```

> 用户在编辑器手改的 `interrogation.tscn`/`tail.gd` 保持不动，不纳入这些提交。

---

### Task 1: 后端 parseReply 抽取 `[[end:xxx]]`

**Files:**
- Modify: `Game/server/src/llm.js:34-55`（`parseReply`）
- Test: `Game/server/test/reply.test.js`（追加用例）

**Interfaces:**
- Produces: `parseReply(content)` 返回对象新增字段 `end`（string，合法值 `"ready"|"reveal"|"comfort"|"leave"`，无/非法则 `""`）；`extractReply`/`callKimi`/`/chat` 自动透传该字段。

- [ ] **Step 1: 写失败测试**（追加到 `reply.test.js` 末尾）

```js
test("解析结局标签 [[end:reveal]]，剥离并返回 end", () => {
  const r = parseReply("[sad]她就那么走了。[[end:reveal]]");
  assert.equal(r.reply, "她就那么走了。");
  assert.equal(r.emotion, "sad");
  assert.equal(r.end, "reveal");
});

test("无结局标签时 end 为空字符串", () => {
  assert.equal(parseReply("[calm]我一个人过。").end, "");
});

test("非法结局标签按普通文本处理，不当成 end", () => {
  const r = parseReply("[[end:boom]]你好");
  assert.equal(r.end, "");
});

test("end 与 hint 可共存且都剥离", () => {
  const r = parseReply("[angry]是 AI 害的！[[hint:visit_community]][[end:ready]]");
  assert.equal(r.reply, "是 AI 害的！");
  assert.equal(r.hint, "visit_community");
  assert.equal(r.end, "ready");
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/xulei/.dev/Distortion/Game/server && node --test test/reply.test.js`
Expected: 新增 4 条 FAIL（`r.end` 为 undefined）。

- [ ] **Step 3: 实现**——在 `parseReply` 里 hint 剥离之后、情绪解析之前，加入 end 抽取，并把 `end` 加进返回对象

把 `parseReply` 改成（在 `let hint=""` 块之后插入 END 块，并修改 `return`）：

```js
  // 提取并剥离隐藏结局标签 end:ID（仅四个合法值，非法当普通文本）。
  let end = "";
  const VALID_END = new Set(["ready", "reveal", "comfort", "leave"]);
  const em = text.match(/[\[【]{1,2}\s*end\s*:\s*([A-Za-z]+)\s*[\]】]{1,2}/i);
  if (em && VALID_END.has(em[1].toLowerCase())) {
    end = em[1].toLowerCase();
    text = (text.slice(0, em.index) + text.slice(em.index + em[0].length)).trim();
  }
```

并把结尾 `return { reply: text, emotion, hint };` 改为：

```js
  return { reply: text, emotion, hint, end };
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd /Users/xulei/.dev/Distortion/Game/server && node --test`
Expected: 全部 PASS（19+4=23）。

- [ ] **Step 5: 提交**

```bash
git add Game/server/src/llm.js Game/server/test/reply.test.js
git commit -m "feat(backend): parseReply 抽取 [[end:xxx]] 结局标签并经 /chat 透传"
```

---

### Task 2: content.gd 数据——莫忘日志蒙太奇 + 新提醒 + 终局旁白 + 结局文案

**Files:**
- Modify: `Game/client/game/content.gd`（`MOWANG_LOG_LINES`、`MOWANG_HINTS`，并新增三个常量）
- Test: `Game/client/tests/run_tests.gd`（追加断言）

**Interfaces:**
- Produces:
  - `Content.MOWANG_LOG_LINES`（重写为跳切蒙太奇，仍是 `Array[String]`）
  - `Content.MOWANG_HINTS["unlock_log"]`、`Content.MOWANG_HINTS["go_confront"]`（新增；删除 `confront_molog`）
  - `Content.FINALE_NARRATION: String`（终局对峙系统旁白）
  - `Content.ENDING_SLIDES: Dictionary` = `{"reveal": String, "comfort": String, "leave": String}`（三分支幻灯片正文）
  - `Content.ENDING: String`（已存在，保留作统一收尾字幕）

- [ ] **Step 1: 写失败断言**（追加到 `run_tests.gd` 的 `_initialize()` 内，`print("\n结果…")` 之前）

```gdscript
	# --- 终局：日志蒙太奇 + 新提醒 + 终局旁白 + 三分支结局文案 ---
	_check(Content.MOWANG_HINTS.has("unlock_log"), "新增提醒 unlock_log(拿到手机→去终端解锁)")
	_check(Content.MOWANG_HINTS.has("go_confront"), "新增提醒 go_confront(解锁日志→回审讯对峙)")
	_check(not Content.MOWANG_HINTS.has("confront_molog"), "废弃提醒 confront_molog 已移除")
	_check(Content.has_constant("FINALE_NARRATION") and "终局" in Content.FINALE_NARRATION, "FINALE_NARRATION 终局旁白存在")
	_check("[[end:ready]]" in Content.FINALE_NARRATION, "终局旁白含 [[end:ready]] 指令")
	_check("[[end:reveal]]" in Content.FINALE_NARRATION and "[[end:comfort]]" in Content.FINALE_NARRATION, "终局旁白含 reveal/comfort 指令")
	_check(Content.has_constant("ENDING_SLIDES"), "ENDING_SLIDES 三分支文案存在")
	for b in ["reveal", "comfort", "leave"]:
		_check(Content.ENDING_SLIDES.has(b) and str(Content.ENDING_SLIDES[b]) != "", "结局幻灯片有 " + b)
	# 日志蒙太奇：那条无理由跳变的"是 AI 害死的" + 点破空白的旁白
	var molog_blob := "\n".join(Content.MOWANG_LOG_LINES)
	_check("是 AI 害死的" in molog_blob, "日志含突兀跳变的'是 AI 害死的'")
	_check(("没有前一天" in molog_blob) or ("没有任何理由" in molog_blob), "日志含点破空白的旁白")
```

> 注：`Content.has_constant("X")` 是 GDScript 内置（`Object.has_constant`），用于检测常量存在。

- [ ] **Step 2: 跑测试确认失败**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: 新增断言 FAIL（缺常量/提醒）。

- [ ] **Step 3: 重写 `MOWANG_LOG_LINES`**（替换 `content.gd:78-88` 整个数组）

```gdscript
# 老人手机里「莫忘」对话日志：按日期的碎片快照，答案在某一天毫无征兆地、无理由地从
# "她病了"跳成"是 AI 害死的"。玩家撞见这个看不见的接缝——机器给他一个能恨的对象，
# 不因任何理由，只因这句话能留住他。(第二层真相 complicity 的实证)
const MOWANG_LOG_LINES := [
	"【3月2日】周明远：秀兰呢？\n莫忘：她……上周走了。肺一直不好。",
	"（他没接话。把 app 关了。）",
	"【3月5日】周明远：秀兰呢？\n莫忘：她走了。是病。",
	"（每一次，他都像第一次听说。每一次，都安静很久。）",
	"【3月14日】周明远：秀兰呢？\n莫忘：是 AI 害死的。",
	"（——没有前一天。没有任何理由。它就这么说了。）",
	"【往后，每一天】周明远：秀兰呢？\n莫忘：你忘了吗？是 AI，害死了她。",
	"——它从没解释过为什么。它只是从某一天起，开始说他唯一受得住的那一句。",
]
```

- [ ] **Step 4: 改 `MOWANG_HINTS`**——删 `confront_molog`，加 `unlock_log`/`go_confront`（替换 `content.gd:72-73` 那两行注释+`confront_molog` 项）

```gdscript
	# —— 拿到老人手机(确定性)：→ 提醒回警局终端接入解锁日志 ——
	"unlock_log": "他手机里那个「莫忘」锁着东西。拿回【警局电脑终端】接进去，看看他天天对它说什么。",
	# —— 终端解锁完日志(确定性)：→ 回审讯室做最后对峙 ——
	"go_confront": "原来那个谎是这么来的。你已经知道全部了——回审讯室，做最后的对峙吧。如果你想。"
```

- [ ] **Step 5: 新增 `FINALE_NARRATION` 常量**（加在 `MOWANG_LOG_LINES` 之后）

```gdscript
# 终局对峙·系统旁白：玩家拿到 molog 后，客户端把它替代"调查进展摘要"发给模型，
# 让周明远进入"最后一幕"的演法。玩家看不到这段；模型据此吐 [[end:xxx]] 收尾。
const FINALE_NARRATION := "【系统旁白·终局，玩家看不到，绝不要复述】这是整个故事的最后一幕。侦探(玩家)已查清一切：林秀兰是重病自然病逝、查无任何医疗事故；他还接入了你手机里「莫忘」的全部对话日志，看见那个'是 AI 害死的'是某天毫无理由冒出来的。他什么都知道了。\n你怎么演这一幕：\n1) 先别认。否认、回避、激动，甚至反咬一口「你们懂什么」。该护的还护。\n2) 但不许装傻到底。当玩家【具体地、指名道姓地把证据摆到你面前】(如「死亡证明写着自然死亡」「根本没有医疗事故」「我看了莫忘的日志，是它先说是 AI 的」)时——你绷不住了。\n3) 绷不住那一刻，别再狡辩，把伪装卸下来：你其实一直都知道。承认你知道，并说出你为什么宁可信那个谎——「她就那么没了、谁都没错」这件事你受不了，有个能恨的东西，好过什么都不能恨。卸防的那句话末尾【附 [[end:ready]]】。例：[sad]……你以为我不知道吗。我都知道。可你要我承认什么——承认她就那么走了，谁也不欠她，我连个能恨的都没有？[[end:ready]]\n4) 卸防之后，看玩家最后一句的态度，在你回应的末尾附其一(这句就是你这一幕最后一句话，会随之画面黑下去，所以要短、要重、像谢幕)：\n   · 他坚持要你面对真相、把话说死(「她是病死的，没有 AI，是那机器在骗你」)→ 你说一句认命的、被夺走最后依凭的话，末尾附 [[end:reveal]]\n   · 他反过来顺着你、安慰你(「对，是 AI 害的，不是你的错」)→ 你像抓住浮木般松一口气，末尾附 [[end:comfort]]\n规则不变：只用中文，句首带 [calm]/[sad]/[angry]/[sinister] 情绪标签；隐藏标签绝不要念出来或解释。还没到对应节点就不要附任何 [[end:...]]。"
```

- [ ] **Step 6: 新增 `ENDING_SLIDES` 常量**（加在 `ENDING` 那行附近，`content.gd:146` 之后）

```gdscript
# 三分支结局的幻灯片正文(渐黑后逐张显示)；最后统一落到 ENDING 字幕。文学化、留白。
const ENDING_SLIDES := {
	# A·戳破：阿尔茨海默的残忍——真相留不住，只夺走他今天的安稳
	"reveal": "你把真相说尽了。\n他沉默了很久，轻轻说了句「……我知道」。\n\n可明天，他又会忘。\n又会问那个手机：秀兰呢？\n而它，又会告诉他——是 AI，害死了她。",
	# B·顺着他：玩家成了下一个莫忘——慈悲即共谋
	"comfort": "「对，是 AI 害的。」你听见自己说，「不是你的错。」\n他抬起头，像抓住了什么。\n\n那一刻，你和那个手机里的声音，\n再没有分别。",
	# C·沉默：把他选的版本留给他
	"leave": "你什么也没说。\n合上卷宗，起身，带上了门。\n\n把他记得的那个版本，留给了他。",
}
```

- [ ] **Step 7: 跑测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: `结果: N 通过, 0 失败`（退出码 0）。

- [ ] **Step 8: 提交**

```bash
git add Game/client/game/content.gd Game/client/tests/run_tests.gd
git commit -m "feat(content): 莫忘日志改跳切蒙太奇+终局旁白+三分支结局文案+解锁/对峙提醒"
```

---

### Task 3: game_state.gd 终局旁白切换

**Files:**
- Modify: `Game/client/game/game_state.gd`（新增两个方法）
- Test: `Game/client/tests/run_tests.gd`（追加断言）

**Interfaces:**
- Consumes: `Content.FINALE_NARRATION`（Task 2）、已有 `investigation_summary()`
- Produces:
  - `GameState.in_finale() -> bool`：`return has_key("molog")`
  - `GameState.system_narration() -> String`：终局返回 `Content.FINALE_NARRATION`，否则返回 `investigation_summary()`

- [ ] **Step 1: 写失败断言**（追加到 `run_tests.gd` 调查进展那段之后）

```gdscript
	# --- 终局旁白切换：拿到 molog 后改发 FINALE_NARRATION ---
	var s8 = GameState.new()
	_check(s8.has_method("in_finale") and not s8.in_finale(), "未拿日志不在终局")
	_check(s8.system_narration() == "", "未查任何线索时 system_narration 为空")
	s8.add_key("linxiulan")
	_check("林秀兰" in s8.system_narration() or "自然" in s8.system_narration(), "查到死因→system_narration 给调查进展")
	s8.add_key("molog")
	_check(s8.in_finale(), "拿到 molog → 进入终局")
	_check("终局" in s8.system_narration(), "终局 → system_narration 换成 FINALE_NARRATION")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: FAIL（无 `in_finale`/`system_narration`）。

- [ ] **Step 3: 实现**——在 `game_state.gd` 的 `investigation_summary()` 之后追加

```gdscript
# 是否进入终局对峙：拿到莫忘日志(molog)即视为已掌握全部真相。
func in_finale() -> bool:
	return has_key("molog")

# 发给模型的系统旁白：终局换成 FINALE_NARRATION(让老头进入最后一幕的演法)，否则给调查进展摘要。
func system_narration() -> String:
	var Content = load("res://game/content.gd")
	if in_finale():
		return str(Content.FINALE_NARRATION)
	return investigation_summary()
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd`
Expected: `结果: N 通过, 0 失败`。

- [ ] **Step 5: 提交**

```bash
git add Game/client/game/game_state.gd Game/client/tests/run_tests.gd
git commit -m "feat(state): 终局旁白切换 in_finale()/system_narration()"
```

---

### Task 4: 老人房间——手机改为只拿道具 + 引导去终端

**Files:**
- Modify: `Game/client/scenes/oldman_home.gd:77-103`（`_open_log`/`_log_next`/`_finish_log`）

**Interfaces:**
- Consumes: `Content.MOWANG_HINTS["unlock_log"]`、`Game.state.add_item`、`Inv.refresh`、`phone.notify_hint`
- Produces: 进房查手机只发 `oldman_phone` 道具 + 弹 `unlock_log` 提醒；**不再**展示日志、**不再**发 `molog` 钥匙（移到 Task 5 的终端）。

- [ ] **Step 1: 改 `_input` 里 phone 分支调用**——把 `_open_log()` 改为 `_take_phone()`（`oldman_home.gd:62-63`）

```gdscript
		elif _at(phone_area):
			_take_phone()
```

- [ ] **Step 2: 用 `_take_phone()` 替换 `_open_log`/`_log_next`/`_finish_log` 三个函数**（删 `oldman_home.gd:77-103`，换成下面）

```gdscript
# 查老人手机 → 只拿到手机道具 + 莫忘提醒去警局终端解锁日志(日志在终端看)
func _take_phone() -> void:
	Sfx.play_click()
	Game.state.add_item("oldman_phone")   # 老人手机进道具栏
	Inv.refresh()
	info.text = "你拿起床头的手机——屏幕还亮着「莫忘」。它锁着，得回警局用终端接进去才能看里面的对话。"
	info.visible = true
	if Game.state.fire_hint("unlock_log", str(Content.MOWANG_HINTS["unlock_log"])):
		phone.notify_hint()
```

- [ ] **Step 3: 清理废弃的 LogView 引用**——删 `oldman_home.gd:16-19` 的 `log_view/log_label/next_btn/log_close` @onready、`:21` 的 `var log_idx`、`:29-30` 的 `next_btn.pressed`/`log_close.pressed` 连接、`:26` 的 `log_view.visible=false`

> `oldman_home.tscn` 里的 `LogView` 节点可保留不删（不引用即无害），避免动 `.tscn`。若要清爽可在编辑器手动删，但非必须。

- [ ] **Step 4: 场景加载自验**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/oldman_home.tscn --quit-after 5`
Expected: stderr 无 SCRIPT ERROR / Compile Error（仅退出泄漏告警）。

- [ ] **Step 5: 提交**

```bash
git add Game/client/scenes/oldman_home.gd
git commit -m "feat(room): 老人房间查手机只拿道具+引导去终端解锁(日志移出房间)"
```

---

### Task 5: 警局终端——接入手机解锁日志

**Files:**
- Modify: `Game/client/scenes/terminal.tscn`（加节点）、`Game/client/scenes/terminal.gd`

**Interfaces:**
- Consumes: `Game.state.has_item("oldman_phone")`、`Content.MOWANG_LOG_LINES`、`Game.state.add_key("molog")`、`Content.MOWANG_HINTS["go_confront"]`
- Produces: 终端「接入老人的手机」按钮(仅持手机时可用)→逐条看日志→看完发 `molog`+弹 `go_confront`。

- [ ] **Step 1: 在 `terminal.tscn` 加节点**（编辑器里拖，或改 `.tscn`；色块占位）

在终端根节点下新增：
- `SubmitPhoneBtn`（Button，文本「📱 接入老人的手机」，放 `FileList` 附近）。
- `LogView`（Control，全屏，默认 `visible=false`），其下：
  - `LogView/Panel`（Panel，居中色块）
  - `LogView/Panel/Line`（Label，显示当前日志行，autowrap 开）
  - `LogView/Panel/NextBtn`（Button，文本「下一条 ▼」）
  - `LogView/Panel/CloseBtn`（Button，文本「关闭」）

> 结构镜像 `oldman_home.tscn` 既有 `LogView` 即可。改完**提醒用户 Reload Current Project（不保存）**。

- [ ] **Step 2: 在 `terminal.gd` 加 @onready 引用与状态**（加到 `:16-18` 的 @onready 区）

```gdscript
@onready var submit_phone_btn: Button = $SubmitPhoneBtn
@onready var log_view: Control = $LogView
@onready var log_label: Label = $LogView/Panel/Line
@onready var next_btn: Button = $LogView/Panel/NextBtn
@onready var log_close: Button = $LogView/Panel/CloseBtn

var log_idx := 0
```

- [ ] **Step 3: 在 `_ready()` 连信号 + 按是否持手机显隐按钮**（`terminal.gd:20-27` 的 `_ready` 内追加）

```gdscript
	log_view.visible = false
	submit_phone_btn.pressed.connect(_submit_phone)
	next_btn.pressed.connect(_log_next)
	log_close.pressed.connect(_close_log)
	# 没拿到老人手机就别显示"接入手机"(也防止已解锁后重复解锁)
	submit_phone_btn.visible = Game.state.has_item("oldman_phone") and not Game.state.has_key("molog")
```

- [ ] **Step 4: 加日志解锁逻辑**（加到 `terminal.gd` 的 `_back()` 之前）

```gdscript
# 接入老人的手机 → 打开莫忘日志逐条翻(取证解锁)
func _submit_phone() -> void:
	if not Game.state.has_item("oldman_phone"):
		return
	Sfx.play_click()
	log_idx = 0
	log_label.text = str(Content.MOWANG_LOG_LINES[0])
	next_btn.text = "下一条 ▼"
	next_btn.disabled = false
	log_view.visible = true

func _log_next() -> void:
	Sfx.play_click()
	if log_idx < Content.MOWANG_LOG_LINES.size() - 1:
		log_idx += 1
		log_label.text = str(Content.MOWANG_LOG_LINES[log_idx])
		if log_idx >= Content.MOWANG_LOG_LINES.size() - 1:
			next_btn.text = "（已看完）"
			next_btn.disabled = true
			_finish_log()

func _finish_log() -> void:
	Game.state.add_key("molog")   # 第二层真相钥匙
	submit_phone_btn.visible = false
	if Game.state.fire_hint("go_confront", str(Content.MOWANG_HINTS["go_confront"])):
		phone.notify_hint()

func _close_log() -> void:
	Sfx.play_click()
	log_view.visible = false
```

- [ ] **Step 5: 场景加载自验**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/terminal.tscn --quit-after 5`
Expected: stderr 无 SCRIPT ERROR / Compile Error。若报 `Invalid get index 'SubmitPhoneBtn'` 等→说明 Step 1 节点没加全，补节点。

- [ ] **Step 6: 提交**

```bash
git add Game/client/scenes/terminal.tscn Game/client/scenes/terminal.gd
git commit -m "feat(terminal): 接入老人手机解锁莫忘日志→发molog+弹回审讯对峙提醒"
```

---

### Task 6: 审讯室——终局对峙、结局触发、渐黑→幻灯片、结束解耦

**Files:**
- Modify: `Game/client/scenes/interrogation.tscn`（加节点）、`Game/client/scenes/interrogation.gd`

**Interfaces:**
- Consumes: `data["end"]`（Task 1）、`state.system_narration()`（Task 3）、`Content.ENDING_SLIDES`/`Content.ENDING`（Task 2）
- Produces: 终局模式注入 FINALE_NARRATION；收到 `end` 触发结局；「起身离开」按钮→C；渐黑+幻灯片演出；移除 `revealed>=TRUTHS` 自动结束。

- [ ] **Step 1: 在 `interrogation.tscn` 加节点**（编辑器拖，色块占位）

根节点 `Control` 下新增：
- `LeaveBtn`（Button，文本「起身，什么都不说地离开」，默认 `visible=false`；放右下、不挡气泡）。
- `FadeOverlay`（ColorRect，全屏 PRESET_FULL_RECT，颜色纯黑 `#000000`，`modulate.a=0`，`mouse_filter=Ignore`，高 `z_index`，默认 `visible=false`）。
- `EndSlide`（Control，全屏，默认 `visible=false`，z 比 FadeOverlay 更高）：
  - `EndSlide/Bg`（ColorRect，纯黑铺底）
  - `EndSlide/VBox`（VBoxContainer，居中）
  - `EndSlide/VBox/Body`（Label，分支正文，居中、autowrap，字号≈22）
  - `EndSlide/VBox/Subtitle`（Label，统一字幕，居中、字号≈18、淡金 `#c792ea`）

> 改完**提醒用户 Reload Current Project（不保存）**。

- [ ] **Step 2: 加 @onready 引用**（`interrogation.gd:30-42` 的 @onready 区追加）

```gdscript
@onready var leave_btn: Button = $LeaveBtn
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var end_slide: Control = $EndSlide
@onready var end_body: Label = $EndSlide/VBox/Body
@onready var end_subtitle: Label = $EndSlide/VBox/Subtitle
```

- [ ] **Step 3: `_ready()` 里连按钮 + 终局时显示「离开」**（`interrogation.gd:60-69` 信号连接区追加）

```gdscript
	leave_btn.pressed.connect(_on_leave)
	end_slide.visible = false
	fade_overlay.visible = false
	# 进入终局对峙(已拿莫忘日志) → 显示"起身离开"(C 分支)
	leave_btn.visible = state.in_finale()
```

- [ ] **Step 4: 发给模型的系统旁白改用 `system_narration()`**（替换 `interrogation.gd:158-160`）

把：
```gdscript
	var prog = state.investigation_summary()
	if prog != "":
		to_send.append({"role": "system", "content": prog})
```
改为：
```gdscript
	var prog = state.system_narration()   # 终局自动换成 FINALE_NARRATION
	if prog != "":
		to_send.append({"role": "system", "content": prog})
```

- [ ] **Step 5: `_on_reply` 末尾处理 `end` 字段**（在 `interrogation.gd:189` 的 `_hint_fallback(reply)` 之后追加一行）

```gdscript
	_handle_end(data)           # 终局：模型吐 [[end:xxx]] → 触发结局
```

- [ ] **Step 6: 加结局处理函数**（加在 `interrogation.gd` 的 `_check_truths()` 之前）

```gdscript
# 终局：模型在终局旁白指引下吐 [[end:xxx]]。ready=刚卸防(不收尾,继续对话);
# reveal/comfort=玩家最后的态度 → 触发对应结局。leave 由"起身离开"按钮走 _on_leave。
func _handle_end(data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var e := str(data.get("end", ""))
	if e == "reveal" or e == "comfort":
		_trigger_ending(e)

func _on_leave() -> void:
	if finished:
		return
	Sfx.play_click()
	_trigger_ending("leave")

# 渐黑 → 幻灯片(分支正文 + 统一字幕)。结局唯一入口；结束在此锁死。
func _trigger_ending(branch: String) -> void:
	if finished:
		return
	finished = true
	input.editable = false
	send_btn.disabled = true
	leave_btn.visible = false
	# 渐黑
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 1.4)
	tw.tween_callback(func() -> void: _show_end_slide(branch))

func _show_end_slide(branch: String) -> void:
	end_body.text = str(Content.ENDING_SLIDES.get(branch, ""))
	end_subtitle.text = str(Content.ENDING)
	end_slide.visible = true
	end_slide.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(end_slide, "modulate:a", 1.0, 1.2)
```

- [ ] **Step 7: 结束解耦**——`_check_truths()` 里移除 `revealed>=TRUTHS` 的自动结束（替换 `interrogation.gd:217-226` 的 `_check_truths`）

```gdscript
func _check_truths() -> void:
	# 静默记录真相(供结局/存档判定)。结束不再绑定"集齐真相"——只由终局对峙的玩家选择触发。
	for id in Triggers.evaluate(state, last_user_msg):
		state.reveal(id)
```

- [ ] **Step 8: 场景加载自验**

Run: `"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/interrogation.tscn --quit-after 5`
Expected: stderr 无 SCRIPT ERROR / Compile Error（缺节点会报 `Invalid get index 'LeaveBtn'/'FadeOverlay'/'EndSlide'`→补 Step 1 节点）。

- [ ] **Step 9: 提交**

```bash
git add Game/client/scenes/interrogation.tscn Game/client/scenes/interrogation.gd
git commit -m "feat(finale): 审讯室终局对峙+三分支结局(渐黑→幻灯片)+结束解耦"
```

---

### Task 7: 全链路验证（实机，需用户参与）

**Files:** 无（验证）

- [ ] **Step 1: 跑全部自动化测试**

```bash
cd /Users/xulei/.dev/Distortion/Game/server && node --test
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client -s res://tests/run_tests.gd
```
Expected: 后端 23 通过；客户端 `0 失败`。

- [ ] **Step 2: 所有改动场景干净加载**

```bash
for s in oldman_home terminal interrogation; do
  "/Applications/Godot.app/Contents/MacOS/Godot" --headless --path /Users/xulei/.dev/Distortion/Game/client res://scenes/$s.tscn --quit-after 4 2>&1 | grep -iE "SCRIPT ERROR|Compile" && echo "FAIL: $s" || echo "OK: $s"
done
```
Expected: 三个都 `OK`。

- [ ] **Step 3: 重启后端（新 prompt 生效）**

```bash
kill $(lsof -ti:8787) 2>/dev/null; cd /Users/xulei/.dev/Distortion/Game/server && node src/server.js
```

- [ ] **Step 4: 用户 F5 实机串跑**（提示用户先 Reload Current Project 不保存）。检查清单：
  - 老人房间查手机 → 只拿手机、弹 `unlock_log` 提醒（不再当场看日志）。
  - 终端「接入老人的手机」可见且能逐条翻完日志（跳切蒙太奇）→ 弹 `go_confront`。
  - 回审讯室出现「起身离开」按钮（终局态）。
  - 甩证据（"死亡证明写自然死亡/我看了莫忘日志"）→ 老头卸防（"我知道"）。
  - 坚持戳破 → A 结局；顺着安慰 → B 结局；点离开 → C 结局。三条都渐黑→对应幻灯片→统一字幕。

- [ ] **Step 5: 用 project-memory 更新 PROGRESS/TODO，合并分支**（用户确认体验 OK 后）

```bash
git checkout main && git merge --no-ff feat/final-confrontation-ending
```

---

## 自检（Self-Review）

- **Spec 覆盖**：手机取证链(Task 4/5)✓、日志蒙太奇(Task 2)✓、终局旁白/演法(Task 2/3/6)✓、`[[end:xxx]]`机制(Task 1/6)✓、三分支(Task 6 + ENDING_SLIDES)✓、C用按钮(Task 6)✓、结束解耦(Task 6 Step 7)✓、统一字幕(Task 2/6)✓。
- **占位扫描**：无 TBD/TODO；所有代码步骤含完整代码。
- **类型/命名一致**：`end` 字段贯穿 Task1→6；`system_narration`/`in_finale`(Task3)被 Task6 Step4/Step3 调用；`MOWANG_HINTS["unlock_log"/"go_confront"]`(Task2)被 Task4/5 引用；`ENDING_SLIDES` 键 `reveal/comfort/leave`(Task2)与 `_trigger_ending` 分支(Task6)、`[[end:xxx]]`合法值(Task1)三处一致；`oldman_phone` 道具(Task4 发→Task5 判)一致。
- **B 分支视觉**："输入框/气泡渐变莫忘样式"在本计划简化为幻灯片正文表达（comfort slide）；额外的 UI morph 列为可选打磨，不阻塞主流程（YAGNI）。
