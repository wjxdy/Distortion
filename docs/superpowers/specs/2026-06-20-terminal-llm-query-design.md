# 终端机 → 自然语言查询机 设计稿

- 日期：2026-06-20
- 分支建议：`feat/terminal-llm-query`
- 范围级别：P0（新机制、跨脚本/场景/数据、引入新 LLM 调用链）

## 一、目标与背景

### 问题
现在警局终端机（`scenes/terminal.tscn` + `terminal.gd`）是**静态展示页**：左侧 5 个文件夹按钮（案件 / 周明远 / 住址 / 林秀兰 / 安葬），点一下就把 `content.gd` 里写死的 `TERMINAL_FILES[id].text` 全文摊到右侧 Label。玩家**点完按钮就什么都知道了**，不用思考——这是当前剧情"玩起来无聊"的主因之一（信息一次性全给、零信息差）。

### 本轮做什么
把终端机改成 **自然语言查询机**：玩家**打字提问**，终端像聊天窗一样**一问一答、历史累积可回看**。回答内容仍来自写死的 `TERMINAL_FILES` 档案——**模型只当检索员，绝不编造事实**。

### 本轮明确不做（留接口，以后改剧情时再做）
- 手机解锁解谜（密码 / 婚姻登记日推算）。
- 改剧情 / 改文案 / 蓝裙子钩子 / 结局演出。知识库**就用现有 `TERMINAL_FILES` 5 条**，正文一字不改，只补检索用的元数据。
- "打通了"电话接通结局、AI 合成语音。

> 一句话：**只换"终端机怎么交互"这一个机制，不碰剧情。** 以后改剧情只需往知识库加数据，机制不动。

## 二、核心设计原则

1. **模型只检索、不创作（零幻觉铁律）**：把"档案清单（id + 标签 + 关键词）"+ 玩家这句问喂给模型，模型**只输出命中的档案 id（或 NONE）**，绝不输出正文。客户端拿 id 去 `TERMINAL_FILES[id].text` 取**写死的原文**显示。→ 事实永远是作者写的，模型碰不到、改不了、编不出新记录。
2. **离线/无 key 也能玩通（永不卡死）**：模型失败 / 超时 / 占位符 401 时，客户端用**同一套关键词在本地兜底匹配**，照样查得到。模型在线 → 更聪明的自然语言理解；模型不在 → 本地关键词照常工作。
3. **聊天式历史可回看**：终端结果区是一个**滚动聊天窗**，玩家问过的每一句 + 终端的每条回答都累积留在屏上、可往回滚。这就是用户要的"终端能看到历史聊天记录"。
4. **项目铁律**：摆着的（输入框 / 按钮 / 聊天窗）进 `.tscn` 当真实可拖节点；脚本只管逻辑（发请求、填字、滚动）。
5. **进度衔接不破**：现有"查到某档案 → 发钥匙（`grants_key`）+ 触发回审讯室的提醒（`FILE_HINTS`）"完全保留，由"模型命中了哪条 id"确定性驱动，不受模型发挥影响。

## 三、检索语义（单条独立检索）

- 屏幕上是连续聊天，但**底层每次查询各自独立**：每次只把【档案清单 + 玩家这一句】喂模型抠 id，**不把聊天历史喂模型**。最稳、最好验证，也避免模型被前文带偏。
- 代价：暂不支持"查完周明远接着问'那他老婆呢'"这种依赖上文的追问。玩家需把对象说全（"林秀兰" / "他老婆" / "周明远的妻子"都能命中，靠关键词覆盖）。真·多轮上下文留作以后增强，不在本轮。

## 四、知识库数据结构（content.gd）

给现有 `TERMINAL_FILES` 每条**加一个 `keywords` 数组**（检索用），**正文 `text`、`grants_key`、`label` 全不动**：

```gd
const TERMINAL_FILES := {
    "case":    { ..., "keywords": ["案件", "报案", "案情", "怎么回事", "发生了什么", "为什么来"] },
    "zhou":    { ..., "keywords": ["周明远", "老头", "老人", "这个人", "他是谁", "什么人", "资料", "背景"] },
    "address": { ..., "keywords": ["住址", "地址", "家", "住哪", "住在哪", "家在哪", "户籍", "小区"] },
    "wife":    { ..., "keywords": ["林秀兰", "妻子", "老婆", "老伴", "他妻子", "她", "夫人", "走丢", "失踪"] },
    "medical": { ..., "keywords": ["安葬", "殡葬", "下葬", "骨灰", "墓", "安和园", "葬在哪", "埋"] },
}
```

> keywords 仅供检索（模型清单 + 本地兜底共用）；玩家看到的依旧只有 `text` 原文。

## 五、检索逻辑（新增 `llm.gd` 函数 + 本地兜底）

新增一组与现有 `build_messages/request_body/parse_reply` 平行的终端专用函数（复用 HTTPRequest / headers / 重试架构）：

| 函数 | 职责 |
|---|---|
| `TERMINAL_SYSTEM_PROMPT` | 教模型当"档案检索 AI"：给定档案清单和用户问题，**只回一个 id 或 NONE**，禁止输出正文/解释/编造。 |
| `build_terminal_messages(query)` | 拼 `[{system: TERMINAL_SYSTEM_PROMPT + 档案清单(id+label+keywords)}, {user: query}]`。 |
| `terminal_request_body(query)` | 复用 `request_body` 模式，低 temperature（0.0~0.2，要确定性）。 |
| `parse_terminal_result(content) -> String` | 从模型输出里抠出合法 id：容忍 `zhou` / `[zhou]` / `id: zhou` / 含多余字时取第一个命中清单的 id；无合法 id → `""`（=NONE）。 |
| `terminal_local_match(query) -> String` | **本地兜底**：把 query 与各条 `keywords` 做包含匹配，返回首个命中的 id，无 → `""`。模型失败时用；也用于单测确定性验证。 |

**terminal.gd 查询流程**：
1. 玩家在输入框打字、回车/点查询 → 把"你：<query>"追加进聊天窗。
2. 发 LLM 请求（`terminal_request_body(query)`）。
3. 成功 → `parse_terminal_result` 抠 id；失败/超时/用尽重试 → `terminal_local_match(query)` 本地兜底抠 id。
4. id 命中 → 把 `TERMINAL_FILES[id].text` 原文追加进聊天窗（"终端：<原文>"）；并执行**现有副作用**：`grants_key` 发钥匙 + `FILE_HINTS` 触发莫忘提醒（沿用 `_show()` 里那段逻辑，抽成 `_grant_and_hint(id)`）。
5. id 为空 → 追加"终端：无匹配记录。试试换个说法，或查某个人 / 某条记录。"
6. 聊天窗滚到底；输入框清空待下次。

> 现有 `_show(file_id)` 的副作用逻辑（发钥匙 + FILE_HINTS）原样保留，只是触发入口从"点按钮"变成"查询命中 id"。

## 六、UI 改造（terminal.tscn）

去掉左侧 5 个文件夹按钮（`FileList` 下 CaseBtn/ZhouBtn/AddressBtn/WifeBtn/MedicalBtn），改为：

- **聊天记录区**：`RichTextLabel`（`scroll_active`，`bbcode` 开，放进 `ScrollContainer` 或自带滚动），累积显示"你：…/终端：…"。替换原 `DisplayBg/Display` 那个 Label。
- **输入行**：底部 `LineEdit`（占位符"输入要查询的内容，回车发送…"）+ `Button`（"查询"）。
- **状态提示**：查询中显示"检索中…"（一个 Label 或直接在聊天窗追加临时行），防止玩家以为卡了（沿用审讯室"等模型"的处理思路）。
- **保留**：`SubmitPhoneBtn`（📱 接入手机·恢复历史日志）+ 整个 `LogView` 莫忘蒙太奇面板 —— **原样不动**，这是另一条线（莫忘历史日志 `MOWANG_LOG_LINES`），与终端聊天历史是两回事。
- **保留**：`BackBtn`（关闭终端）、`Header`、`Dim`、`Panel`。

> 改完 `.tscn` 后提醒用户在编辑器 **Reload Saved Scene**。新增 LineEdit/Button/RichTextLabel 都作为真实节点摆进场景树，可拖可调。

## 七、错误处理与边界

- 模型调用：复用审讯室的重试（MAX_TRIES=3，递增延迟）。用尽 → **不报错、不卡死**，转本地 `terminal_local_match` 兜底。
- 没填 key（占位符 401）：第一次失败即转本地兜底；终端照常可用。
- 空输入 / 纯空格：不发请求，提示"请输入要查询的内容"。
- 模型返回不在清单里的 id：`parse_terminal_result` 视为 NONE。
- 聊天历史只存在于本次终端会话（`terminal.gd` 内的 Array + RichTextLabel）；关闭再打开是否保留历史 → **保留本局已查记录**（存进 `terminal.gd` 成员变量，重开终端重新渲染；不跨场景持久化，YAGNI）。

## 八、验证（硬性验收门槛）

### 1. 确定性单测（`tests/run_tests.gd`，headless，必须全绿）
- `parse_terminal_result`：从 `"zhou"` / `"[zhou]"` / `"id: zhou"` / `"应该是 wife 这条"` / `"NONE"` / `"没有"` 各种输出抠 id 正确；未知 id → `""`。
- `terminal_local_match`："他住哪" → address、"他老婆" → wife、"安葬在哪" → medical、"今天天气" → ""（无匹配）。
- id → 正文 / `grants_key` 映射正确（命中 wife 给 linxiulan、medical 给 farewell、address 给 home_address）。
- 终端场景带新节点（LineEdit/Button/RichTextLabel）能加载、`@onready` 引用不为 null。
- 既有 `test_terminal_room.gd` 更新：不再断言 5 个文件夹按钮，改断言查询输入框 + 聊天窗存在；`SubmitPhoneBtn` / `LogView` 仍在。

### 2. 真模型实测（用户提出的硬要求 —— 必做，不能只跑 headless）
沿用既有 `/tmp` 真 key 调优脚本模式（或 godot-mcp 跑起来手输），用**真 Moonshot key** 发真实查询，把模型**实际输出贴出来核对**，三类都必须符合预期才算这机制做完：
- **问档案里有的**（周明远 / 他住哪 / 他老婆 / 安葬在哪 / 案件）→ 各自命中正确 id，显示的是写死原文（不改写、不漏字）。
- **问档案里没有的**（天气 / 股票 / 无关人物）→ 老实回"无匹配记录"，**不瞎编**。
- **不泄底**：不会把 5 条一次性全吐，不编造清单外的新记录。

> 需要真 key（编辑器/脚本跑前在设置或脚本里填 Moonshot key，仓库内置是占位符会 401）。实测时会提醒用户。

## 九、不在本轮范围（YAGNI / 留接口）
- 多轮上下文追问（依赖上文的"那他老婆呢"）。
- 知识库门控解锁（某记录要先拿到前置线索才查得到）——现有 `grants_key` 是"查到就发钥匙"，本轮不加"查询门控"。
- 手机解锁解谜、改剧情、蓝裙子、结局演出、电话接通线。

## 十、影响文件清单
| 文件 | 改动 |
|---|---|
| `game/content.gd` | `TERMINAL_FILES` 每条加 `keywords`（正文不动） |
| `game/llm.gd` | 新增 TERMINAL_SYSTEM_PROMPT / build_terminal_messages / terminal_request_body / parse_terminal_result / terminal_local_match |
| `scenes/terminal.tscn` | 删 5 文件夹按钮；加 LineEdit + 查询 Button + RichTextLabel 聊天窗；保留 SubmitPhoneBtn/LogView/BackBtn |
| `scenes/terminal.gd` | 查询发送 / 解析 / 兜底 / 聊天窗渲染 / 滚动；`_show` 副作用抽成 `_grant_and_hint(id)` |
| `tests/run_tests.gd` | 加 parse_terminal_result / terminal_local_match / id 映射断言 |
| `tests/test_terminal_room.gd` | 更新节点断言 |
