# 隐藏电话结局线 设计稿

- 日期：2026-06-20
- 分支：`feat/finale-emergent-ending`
- 范围级别：P0（新结局分支 + 提示词改动 + 跨脚本编排）
- 渊源：原终局设计稿 `2026-06-19-finale-emergent-ending-design.md` §十三 留接口的"打通了"反转，现在落地（简化版：**纯文字、无音频合成**）。

## 一、目标

在审讯室对话中加一条**隐藏支线结局**：玩家若问起老人"为什么总打电话"，再追问"你是怎么打通的"，就触发一个诡异的"电话打通了"结局——老人给亡妻打电话、诡异地接通了，AI 现写一段留白结局并评一个称号。**纯文字呈现，不做语音合成。**

## 二、已定决策（brainstorming 确认）

- **随时可触发**：不需要先拿莫忘日志（molog）/进入终局；在审讯室任何阶段都能走这条线。
- **两步触发**（防误触）：先问"为什么打电话"解锁 → 再问"怎么打通的"触发结局。
- **基调诡异、不揭破、无音频**：电话"打通了"，但不点破是谁接的（不写"AI 合成语音"那层）；留白、瘆人。
- **AI 现写结局总结 + AI 评称号**：复用现有终局画面与称号系统。

## 三、触发机制（确定性，玩家发言关键词）

检测逻辑做成 `llm.gd` 的**静态纯函数**（输入字符串、返回 bool），便于 `run_tests.gd` 直接单测；`interrogation.gd` 的 `_send()` 调用它们：

### 第一步·解锁
`LLM.asks_why_calls(msg) -> bool`：命中以下任一 → `state.phone_line_unlocked = true`，随后**照常走正常 LLM 发送**（老人由模型回话，人设让他在被问到时说"我常给秀兰打电话、打得通"）。
- 关键词：`打电话`、`老打电话`、`总打电话`、`常打电话`、`打给谁`、`给谁打`、`电话`（简单子串包含即可）。

### 第二步·触发结局
`LLM.asks_how_connected(msg) -> bool`：**仅当 `state.phone_line_unlocked` 为真** 且 命中以下任一 → 触发电话结局 `_trigger_phone_ending()`，**不再走正常 LLM 发送**。
- 关键词：`打通`、`接通`、`怎么打的通`、`怎么打通`、`通了吗`、`能打通`。

> `phone_line_unlocked` 存在 `game_state`（随新游戏=新 GameState 重置）。`_send()` 里的门控即 `if state.phone_line_unlocked and LLM.asks_how_connected(msg): _trigger_phone_ending(); return`，其后再 `if LLM.asks_why_calls(msg): state.phone_line_unlocked = true`（同一句最多前进一步：先判触发、未触发再判解锁）。

## 四、老人电话人设（加进提示词）

在 `llm.gd` 的 `SYSTEM_PROMPT` 与 `FINALE_SYSTEM_PROMPT` 各加一小段（**因为随时可触发，正常态和终局态都要有**）：

> 【关于电话（只在被直接问到时才提，平时绝不主动说）】
> 你天天给秀兰打电话。在你的认知里，电话总能打通，她在那头接、你们说上几句。
> 被问到你为什么总打电话、给谁打电话时，你才平静地说：你给秀兰打、电话打得通、她会接。
> 被追问"你是怎么打通的"时，你不解释原理，只笃定地说她就是接了——（你会摸出手机，要拨给她）。

要点：**只在被问到才提**（藏住，不主动剧透）；深化妄想，不揭破谜底；不写"AI 合成"。

## 五、结局演出（复用现有 `_trigger_ending_emergent`）

`_trigger_phone_ending()` 流程：
1. 先把玩家这句"你怎么打通的？"弹成玩家气泡 + 进历史（和正常发送一致的前半段）。
2. 弹一句**脚本化的老人收尾台词**（固定，不走模型）：例如
   `[sad]你不信？……我拨给你看。（他摸出手机，按下那串号码，把听筒凑到你耳边）……你听。`
   （作为他的"最终一句"，进 zhou 气泡 + 历史。）
3. 标记 `finished` 流程进入收尾，渐黑。
4. 渐黑后 **AI 现写 epilogue**：发 `phone_epilogue_request_body(history)`（新 `PhoneHttp` 节点）→ `_on_phone_epilogue` 解析为 epilogue 文本；失败/超时/空 → 兜底 `Content.ENDING_PHONE_FALLBACK`。
5. 拿到 epilogue → 调 `_trigger_ending_emergent(epilogue)`（**复用**：它负责藏 HUD、发称号请求 `title_request_body(history, "call")`、渐黑、显示 EndSlide 的 epilogue + 称号）。

> 即：电话结局把"AI 写 epilogue"这步用**专属电话提示词**做（区别于现有 director 的 truth/comfort 判定），其余渐黑/称号/结局画面全部复用 `_trigger_ending_emergent` 既有逻辑，不重造。

### llm.gd 新增
- `PHONE_EPILOGUE_PROMPT`：给定对话，写 2-4 句留白、克制、诡异的"电话打通了"结局旁白；**不点破是谁接的、不写合成语音、不写血腥/自杀的具体画面**；和现有 director epilogue 同风格（不写金句格言）。
- `build_phone_epilogue_messages(history) -> Array`、`phone_epilogue_request_body(history) -> String`（低温度 0.7 偏文学）。
- `parse_phone_epilogue(content) -> String`：取正文、剥首尾空白；空则返回 ""（调用方兜底）。

### content.gd 新增
- `ENDING_PHONE_FALLBACK`：AI 不可用时的固定 epilogue。诡异、留白，例如：
  `电话接通了。\n听筒里很静，又好像有谁，在很远的地方，轻轻应了一声。\n他笑了，把听筒贴得更紧。`

## 六、数据 / 节点 / 重置

- `game_state.gd`：`var phone_line_unlocked := false`（随新游戏重置，无需额外代码——新 GameState 即清零）。
- `interrogation.tscn`：新增 `PhoneHttp`（HTTPRequest 节点，逻辑节点，沿用 DirectorHttp/TitleHttp 同款摆法），`_ready` 连 `request_completed` → `_on_phone_epilogue`，设 timeout（如 14s）。
- 触发后置 `finished`/锁输入，避免重复触发或继续对话（沿用现有结局的 finished 机制）。

## 七、边界与错误处理

- 第二步关键词在**未解锁**时命中：忽略（照常走正常 LLM）。防止玩家一上来就问"打通了吗"直接跳结局。
- AI epilogue 失败/超时/空 → `ENDING_PHONE_FALLBACK`，结局照常出。
- 称号请求失败 → 复用现有 `_on_title` 兜底（"过客"）。
- 已 `finished`（任意结局已触发）后再检测 → 不重复触发。
- 玩家同一句同时像"为什么打电话"又像"怎么打通"：先判第二步（已解锁才触发），未解锁则只解锁、不触发——同一句话最多前进一步。

## 八、验证（验收门槛）

### headless 单测（`tests/run_tests.gd`，全绿）
- `LLM.asks_why_calls`：命中"你为什么老打电话"→true、"打给谁"→true、"今天天气"→false。
- `LLM.asks_how_connected`：命中"你是怎么打通的"→true、"接通了吗"→true、"她在哪"→false。
- 两步门控（用 GameState 状态断言）：`phone_line_unlocked=false` 时，`phone_line_unlocked and LLM.asks_how_connected("怎么打通的")` 为 false（不触发）；置 `phone_line_unlocked=true` 后同式为 true（触发）。
- `game_state.phone_line_unlocked` 默认 false；新 GameState 为 false。
- `LLM.PHONE_EPILOGUE_PROMPT` 非空；`Content.ENDING_PHONE_FALLBACK` 非空。
- `LLM.SYSTEM_PROMPT` 与 `FINALE_SYSTEM_PROMPT` 均含电话元素（断言含"打电话"或"打通"且"只在被问到"语义的标记词）。
- 场景：`interrogation.tscn` 含新 `PhoneHttp` 节点、能加载。

### 真 key 实测（必做）
真 Moonshot key 跑一遍这条线：审讯中问"你为什么老给人打电话"→ 老头说常给妻子打、打得通 → 问"那你怎么打通的"→ 触发结局 → 看老头收尾台词 + AI 现写的诡异 epilogue + 称号。核对：① 未先问就直接问"打通了吗"不触发；② epilogue 诡异留白、不揭破、不出金句。

## 九、不在本轮范围（YAGNI）
- **无音频 / 无语音合成**（用户明确：没时间做语音）。
- 不揭破"AI 合成亡妻语音"那层谜底（保持诡异留白）。
- 不改现有 truth/comfort 两个终局分支。
- 通话记录里"已接通 N 分钟"那种 UI 物证（原 §十三 的）不做。

## 十、影响文件清单
| 文件 | 改动 |
|---|---|
| `game/llm.gd` | 人设加电话元素(2处提示词) + 静态检测 `asks_why_calls`/`asks_how_connected` + `PHONE_EPILOGUE_PROMPT`/`build_phone_epilogue_messages`/`phone_epilogue_request_body`/`parse_phone_epilogue` |
| `game/game_state.gd` | `phone_line_unlocked` flag |
| `game/content.gd` | `ENDING_PHONE_FALLBACK` |
| `scenes/interrogation.gd` | `_asks_why_calls`/`_asks_how_connected`/门控 + `_trigger_phone_ending`/`_on_phone_epilogue`（复用 `_trigger_ending_emergent`） |
| `scenes/interrogation.tscn` | 新增 `PhoneHttp` HTTPRequest 节点 |
| `tests/run_tests.gd` | 检测/门控/兜底/提示词/节点断言 |
