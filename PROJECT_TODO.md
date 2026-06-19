# 项目待办

## 下一步
- [ ] **【进行中·分支 feat/finale-emergent-ending】终局重构 + 失踪妻子剧情改版**：设计稿已定+提交(62db481)，实现计划已拆任务。范围见 spec `docs/superpowers/specs/2026-06-19-finale-emergent-ending-design.md`。
  - [x] **Task A1**（8986a6a）：content.gd 终端/档案文案 + no_accident→farewell + 两层真相关键词（TDD 98/98）
  - [x] **Task A2**（1604d34）：莫忘滑坡日志改"她走丢了会回来" + 今日对话 + BOSS_TASK + MOWANG_HINTS + 邻居台词对齐失踪妻子剧情（TDD 99/99）
  - [x] **Task B1**（24469c0）：content.gd 新增 4 张证据手牌 EVIDENCE_CARDS + 结局兜底正文 ENDING_FALLBACK（TDD 105/105）
  - [x] **Task B2+C0**（faa7b50）：game_state.gd 新增 presented/present_evidence/presented_proofs + 删 investigation_summary/PROGRESS_FACTS；interrogation.gd:182 最小替换；run_tests.gd 清旧断言+加新断言（TDD 105/105）
  - [x] **Task C1**（a6678c9）：llm.gd SYSTEM_PROMPT 改失踪妻子人设 + FINALE_SYSTEM_PROMPT 改 roleplay 只演不吐结局（含逐层卸防）；run_tests.gd 加三条断言（TDD 108/108）
  - [x] **Task C2**（d8489bf）：parse_reply 移除旧 end 标签逻辑（删 VALID_END + end 剥离块 + end 字段）；run_tests.gd 加4条断言/更新3条（TDD 111/111）
  - [x] **Task C3**（4ef995d）：llm.gd 新增 DIRECTOR_PROMPT + build_director_messages + director_request_body + parse_director（JSON容错）；run_tests.gd 加4条断言（TDD 115/115）
  - [x] **Task D1**（186bdce）：interrogation.tscn 删 LeaveBtn + 加 Evidence 面板(4 toggle Button) + DirectorHttp；interrogation.gd 删 leave_btn 全部引用；新建 test_interrogation_struct.gd（TDD 115/115）
  - [x] **Task D2**（77b5f6b）：interrogation.gd 证据手牌点亮/出示结算 + _send 重写 + presented旁白整审讯注入；_refresh_cards() 含空面板隐藏；test_interrogation_struct.gd 补全4张牌断言（TDD 115/115）
  - [ ] **Task B（剩余）**：上司任务 + hint 文案改版
  - [ ] **Task D3**：hint_fallback 逻辑改失踪语境 + 老头/裁判双调用结局系统（DirectorHttp 已在 tscn 中，@onready 已在 D2 接好）
  - **延后第二阶段(留接口)**：通话记录"打通了"恐怖反转+当场打电话结局+AI合成语音。
- [ ] **合并终局分支**：`feat/final-confrontation-ending`(10 提交，用户 F5 确认 OK) 合回 main。注意：合并前 main 工作区有用户并行在做的脚步声/BGM/music autoload 等未提交改动，别误带。
- [x] ~~剧情去邪教版【客户端】全流程落地~~（已完成）：步骤A数据→手机中枢→phone复用→警局终端→小区支线→道具栏/钥匙→**终局对峙+三分支结局**(A戳破/B顺着他=模型 [[end:reveal/comfort]]/C沉默按钮，结束已解耦)。
- [ ] **剧本零碎收尾(可选打磨)**：线索1「我没有家人」开场、线索7「记记日常」回避目前靠 LLM 人设演，未做成固定脚本节点；出示证据(合照/诊断书)未做显式交互；B 分支"输入框渐变成莫忘样式"暂以幻灯片正文表达，可后补 UI 渐变。
- [ ] 小区/档案室/终端日志面板等场景**美术替换**(现全色块占位) + 房间证物/邻居可再丰富。
- [ ] 主世界街道 F5 微调：背景=**动态落雨城市**(`world_rain_city.tres`,12帧)在 `ParallaxBackground/RainLayer`(横向 motion_scale=0.3 视差)，前景=主街 `world_street_road.png`。待用户实机看：① 视差漂移手感(0.3 太快/太慢可在 RainLayer 改)；② 雨夜明暗/雨量；③ 背景透出与缩放(可拖 FarCity 调"多远")；④ 墙带/门位/Player 起点。满意后无需再动。(`world_far_city.png` 已弃用。)
- [ ] F5 调开场 2D 假 HD-2D 氛围：辉光阈值(Compatibility 下可能需调 `glow_hdr_threshold`)、暗角强度、雨/尘密度；不满意可关某节点。
- [ ] 用 Godot 实机跑通新版完整流程（需后端在跑）：序幕 4 幕 -> 手机来电 -> 审讯气泡对话 -> 查档案 -> 追问蓝裙子/林秀兰 -> 真相裂痕 -> 结尾。重点看：气泡/尖尖位置、打字机手感、Ken Burns、真相 fx_crack 演出、回看记录。
- [ ] 确认最终模型/云产品路线：继续用 Kimi/OpenAI 兼容接口（现默认 moonshot-v1-32k），还是改回腾讯云大模型 + SCF。
- [ ] Moonshot 过载恢复后实测 moonshot-v1-32k 真实速度（subagent 实测正常 TTFB 约 **4~6s**，不是之前以为的 ~1s）；恢复后老头应能 4~6s 正常回话。超时已调到 14s 不会再误杀正常回复。
- [ ] 体验优化（可选）：客户端在等模型时显示"思考中/打字"指示，避免过载时玩家干等（保底沉默约 12s 才出「……」）。保底沉默触发次数/超时/重试在 `llm.js` 顶部常量可调。
- [ ] 音乐（BGM）：用户后期实现，`opening.gd`/`interrogation.gd` 已留挂载点注释。

## 进行中
- [ ] **场景出生点锚点·F5 微调**（机制已落地提交 43657fa）：各可走场景 `.tscn` 里 `Spawns/` 下的 `Marker2D` 锚点初始摆在各门附近,用户进出实机看落点是否贴门、自然,不合适直接在编辑器拖那些 Marker2D 即可(脚本不用动)。锚点名↔门映射见 PROGRESS 2026-06-18 条。

- [ ] 莫忘提醒系统·实机验证 + 扩充：① Moonshot 不忙时实机确认模型真的会在节点输出 `[[hint:ID]]`（若漏触发率高，再考虑加关键词兜底）；② 顺剧情补更多提醒节点（查到死因后→回去追问、第二层真相相关等），文案加进 `content.gd MOWANG_HINTS` + `oldman.js` 指示对应 ID。
- [ ] 警局走廊 F5 微调：真背景已接入(原生满屏)+ 可走 floor 带(墙 Top526/Bottom772)+ **人物已放大 scale1.4 配门比例**。待用户看：人物大小是否合适(嫌小就调 Player scale)、floor 带纵向高度、三门区是否对准图里门、Player 起点。门映射:左门=街道/带窗厚门=审讯室/右侧机房开门=终端室。
- [ ] MVP 核心审讯闭环打磨。
- [ ] 实机验证 AI 自驱表情：开后端发消息，确认模型句首 `[情绪]` 标签被正确解析、立绘随之切换（离线只验证了 parseReply 单测 + 客户端 _set_emotion 截图）。验收通过后删 `interrogation.gd` 临时 F1-F4 调试键。

## 待确认
- [ ] 赛事是否强制指定腾讯云产品、模型或部署方式。
- [ ] 最终路演版本是本地 demo、HTML5 静态导出 + 后端代理，还是完整云端部署。

## 阻塞
- [ ] 未确认可用的模型 API 密钥和目标部署环境。

## 后续可做
- [ ] 对话历史精简：聊太长时把更早对话压成摘要塞回上下文(省 token/稳上下文)。当前历史已跨场景保留+调查进展已喂模型，超长再做。
- [ ] 对话存档功能：跨会话持久化(存盘/读盘)，后续实现。(注：单局内对话已靠全局 Game.state 保留)
- [ ] 增加第二个线索/真相点。
- [ ] 增加更稳定的离线保底回复，降低现场模型波动风险。
- [ ] 真相碎片演出可再加强（目前 fx_crack 淡入淡出 + 金色横幅 + reveal 音）。
- [ ] 气泡过长时与立绘可能轻微重叠，可按需微调垂直布局。
