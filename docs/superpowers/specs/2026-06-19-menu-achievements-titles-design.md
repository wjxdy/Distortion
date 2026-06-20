# 主菜单 + 成就称号系统 设计稿

> 日期：2026-06-19　分支：`feat/finale-emergent-ending`（接在终局结局系统之上）
> 范围：① 启动主菜单；② AI 在每次大结局后按整局对话评一个 **≤10 字称号**；③ 称号持久化为成就收藏（去重）；④ 成就面板查看收藏；⑤ 结局画面闭环（显示称号 + 返回主菜单/查看成就）。
> **不做中途存档**（用户拍板）：开始游戏永远是新一局；唯一持久化的是成就/称号集合。

## 已确认决策
1. 存档范围：**只持久化成就/称号 + 新开局**（无中途存档/读档）。
2. 成就内容：**只收 AI 评的称号**（不做预设里程碑）。
3. 称号去重：**同名只计一次**。
4. 称号长度：**≤10 字**（代码兜死，超截断；异常给兜底「过客」）。
5. 在 `feat/finale-emergent-ending` 分支上继续开发，与终局一起 F5/合并。

## 组件

### 1. 主菜单 `scenes/main_menu.tscn` + `.gd`（新；设为 `run/main_scene`）
- 标题「失真 Distortion」+ 三按钮：**开始游戏**(→`opening.tscn`，新一局)/ **成就**(→成就面板)/ **退出**(`get_tree().quit()`)。
- Zpix 像素风、色块占位（可拖）。脚本只连按钮信号。
- 进菜单播放菜单/开场音乐（复用 `Music.play_opening()`）。

### 2. 称号持久化 autoload `Titles` `game/titles.gd`（新；project.godot 注册）
- 存 `user://achievements.cfg`（ConfigFile，section `titles`）。
- API：
  - `add_title(t: String) -> bool`——去重存入并落盘，返回 true=新获得 / false=已有。
  - `all_titles() -> Array`——按获得顺序返回全部称号。
  - `count() -> int` / `has(t: String) -> bool`。
- `_ready` 自动从 `CFG_PATH` 读入内存 `_titles`。为可测：内部 `_load_from(path)`/`_save_to(path)`，公开方法用默认 `CFG_PATH`。

### 3. AI 称号生成（`game/llm.gd` 加第三个调用，套路同裁判）
- `TITLE_PROMPT`：你是这个叙事侦探游戏的"称号评定官"。根据玩家(侦探)这一局与老人周明远的**全部对话**和**结局类型**，给玩家起一个**≤10 字**、凝练有态度、像成就称号的短语。只输出称号本身，不要解释、不要标点包裹。
- `build_title_messages(history: Array, ending_kind: String) -> Array`——system=TITLE_PROMPT，user=结局类型 + 对话记录。
- `title_request_body(history, ending_kind) -> String`（temperature ~0.7，要点创意）。
- `parse_title(content: String) -> String`——strip、去引号/标点包裹、**截断到 ≤10 字**；为空/异常返回 `""`（调用方兜底「过客」）。

### 4. 结局集成（`scenes/interrogation.gd` + `.tscn`）
- `interrogation.tscn`：① `EndSlide` 加一行 `TitleLabel`（显示「你获得称号：XXX」）；② 加 `BackToMenuBtn`、`ViewAchieveBtn` 两个按钮；③ 加 `TitleHttp`(HTTPRequest)。
- `_trigger_ending_emergent` 时：渐黑→显示 epilogue→**并行发称号请求**（`TitleHttp.request(... LLM.title_request_body(state.history, _pending_end.kind))`）。
- `_on_title(...)`：解析→`var t = LLM.parse_title(...); if t == "": t = "过客"`→`var is_new = Titles.add_title(t)`→在 `TitleLabel` 显示「你获得称号：**t**」+（新 ? "（新！）" : ""）。
- `BackToMenuBtn`→`change_scene_to_file(main_menu.tscn)`；`ViewAchieveBtn`→打开成就面板（或切场景）。

### 5. 成就面板 `scenes/achievements.tscn` + `.gd`（新）
- 顶部「已获得 N 个称号」+ 可滚动 `ScrollContainer`/`Label`（单 Label 填 `all_titles()` join 换行——不脚本造控件，符合铁律）。
- 「返回」按钮回上一处（主菜单）。从主菜单 + 结局画面可达。

## 数据流
```
main_menu[开始游戏] → opening → …通关… → 终局裁判 end=true(kind)
  → 渐黑→显示 epilogue + 并行 TitleHttp(history+kind)
  → parse_title(≤10字,兜底过客) → Titles.add_title(去重落盘) → 显示"称号:XXX(新!)"
  → [返回主菜单]/[查看成就]
achievements ← Titles.all_titles() ← user://achievements.cfg
```

## 错误处理
- 称号请求失败/超时/空 → 兜底「过客」，仍记入（保证每局都有称号）。
- `parse_title` 截断 >10 字、剥首尾引号/句号/方括号。
- `add_title` 去重：同名 cfg 里已存在则不重复、返回 false。
- 称号请求与结局演出并行；称号没回来前 `TitleLabel` 暂空，回来再亮（不阻塞 epilogue/按钮）。
- 主菜单设为启动场景后，`opening` 仍 `Game.reset()` 保证新一局干净。

## 测试
- `parse_title`：≤10 字截断、剥引号标点、空输入→""。
- `Titles`：add 去重(同名 false)、count、all 顺序、`_save_to`/`_load_from` 临时路径 round-trip（不污染真实存档）。
- `build_title_messages`：system=TITLE_PROMPT、带结局类型+对话。
- 结构测试：main_menu(三按钮)、achievements(列表+返回)、interrogation(TitleLabel/BackToMenuBtn/ViewAchieveBtn/TitleHttp 存在)。
- 场景无头加载：main_menu/achievements/interrogation 干净。
- LLM 行为：真 key 抽查称号 ≤10 字、贴合对话（脚本验证，非单测）。

## 涉及文件
| 文件 | 改动 |
|---|---|
| `scenes/main_menu.tscn`/`.gd` | 新建主菜单 |
| `scenes/achievements.tscn`/`.gd` | 新建成就面板 |
| `game/titles.gd` | 新建 Titles autoload(持久化) |
| `game/llm.gd` | 加 TITLE_PROMPT/build_title_messages/title_request_body/parse_title |
| `scenes/interrogation.gd`/`.tscn` | TitleHttp + 结局发称号请求 + TitleLabel/返回菜单/查看成就按钮 |
| `project.godot` | run/main_scene→main_menu；注册 Titles autoload |
| `tests/` | 新增/扩展单测 + 结构测试 |
