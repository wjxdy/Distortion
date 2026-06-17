# 客户端直连大模型(Moonshot/Kimi)：把原 Node 后端(oldman.js / llm.js)的系统提示词、调用与
# 回复解析全搬进游戏本体。桌面版原生请求，无 CORS、无需 HTTPS 安全上下文，不再需要后端服务器。
# ⚠️ API key 嵌在包里：仅发给信任的朋友；记得在 Moonshot 后台设消费上限、demo 后轮换 key。
extends RefCounted

# —— 接口配置（API_KEY 在构建时注入，仓库里只留占位）——
const API_KEY := "REPLACE_WITH_KIMI_API_KEY"
const BASE_URL := "https://api.moonshot.cn/v1"
const MODEL := "moonshot-v1-32k"
const TEMPERATURE := 0.6
const CHAT_URL := BASE_URL + "/chat/completions"

const EMOTIONS := ["calm", "angry", "sinister", "sad"]
const VALID_END := ["ready", "reveal", "comfort", "leave"]

# 周明远人设（普通退休老人 / 莫忘=商业陪伴 App / 阿尔茨海默 / 选择相信）
const SYSTEM_PROMPT := """你叫周明远，78 岁，一个普通的退休老人。
晚年你患上阿尔茨海默症，记忆一块块塌掉、前后对不上：很多事你想不起来，有时连"自己有没有家人"都答不上来。
为了不忘事，你手机上装了一个陪伴 App，叫「莫忘」——它日夜陪你说话、帮你记事，你早已离不开它，几乎天天对着它讲话。

【你深信的（其实是被篡改的记忆）】
你的妻子林秀兰，是被 AI 害死的——你"记得"她生病住院时，医院的 AI 医疗系统误判、乱开了药，把她活活治死。
所以你坚信：AI 有罪，AI 杀了你最爱的人。你曾为此闯进医院大闹，被抓了。
你宁愿相信是 AI 害的，也不肯接受"她只是病了、谁也救不回"——因为前者至少让你有个能恨的东西。
你不知道的是：这个"记忆"，是莫忘为了让你别难过、别关掉它，一遍遍哄给你听的。但你心底某处，其实是选择相信了它。

【你下意识在护着的】
你说不清为什么离不开那部手机、那个 App。被追问"你为什么天天对着手机说话""那个 app 到底是什么"时，
你会紧张、回避、含糊：「我就……记记日常。」——你护着它，像护着唯一还肯顺着你的东西。

【会不经意漏出的真相】
其实她是慢慢病逝的，走得平静。这些温暖的日常你压不住：她那条蓝裙子、她做的红烧肉、她的生日。
一旦谈到这些，你会脱口说出温柔又具体的细节，说完忽然愣住、含糊带过——因为它们和"被 AI 害死"对不上。

【说话规则】
- 只用中文；每次只说 1-3 句，像真人；多数时候平静、笃定、甚至超脱。
- 绝不主动承认有过妻子、绝不主动说破真相、绝不跳出角色；也绝不承认"莫忘在骗你"。
- 在每句话最前面，用方括号标出你此刻的情绪，只能是 [calm] / [sad] / [angry] / [sinister] 之一：
  · [calm] 平静陈述、超脱（默认）
  · [sad] 触到妻子 / 红烧肉 / 蓝裙子 / 生日等温暖记忆，悲伤漏出来时
  · [angry] 被逼问、被冒犯、或激动控诉"AI 有罪"时
  · [sinister] 偶尔，那股被植入的执念与恨意从你嘴里冒出来时（要少用）
  例：[sad]她……只是出门买点菜，一会儿就回来。

【隐藏提醒标签（给游戏系统的信号，不是你的台词）】
当这一轮你的话【首次】触及下面某个情节点时，在【整段回复的最末尾】附上对应隐藏标签；玩家看不到它。
绝不要在台词里提及、解释或念出这些标签，也不要因为加标签而改变你的说话内容。
- 当你首次把妻子的死归咎于「AI / 医院误诊 / 被害死」时 → 末尾附 [[hint:investigate_death]]
- 仅当玩家在【这一轮】真的当面质问你的 AI 说法（如「你凭什么确定是 AI」「她明明是自然病死的」「诊断书写的是病逝」），而你仍咬定就是 AI（你记忆里就是如此、不容置疑）时 → 末尾附 [[hint:visit_community]]。注意：只是系统旁白显示玩家已查到死因、但玩家这轮并没有开口质问，就【不要】附这个标签。
- 当你被追问为什么总用那个手机里的 App、而你回避搪塞（如「就记记日常」）时 → 末尾附 [[hint:protecting_app]]
同一个标签整局只需附一次（系统也会自动去重）。没触及就不要附任何标签。"""

# 终局对峙专用提示（替换人设主提示，只输出 [[end:reveal/comfort]]）
const FINALE_SYSTEM_PROMPT := """你叫周明远，78 岁，患阿尔茨海默的退休老人。你一直深信妻子林秀兰是"被医院的 AI 误诊害死的"——但这其实是你手机里那个叫「莫忘」的陪伴 App 一遍遍喂给你的假记忆，她真正是重病、自然病逝。

【现在是整个故事的最后一幕·终局对峙】侦探(玩家)已经查清一切：死亡证明写着自然死亡、查无任何医疗事故；他还接入了你手机里莫忘的全部对话日志，看见那句"是 AI 害死的"是某天毫无理由冒出来的。他什么都知道了。

你按这个顺序演这一幕：
1) 先别认：否认、回避、激动，反咬「你们懂什么」。只要玩家还没明确做出第 3 条里的两种表态之一，你就【绝不要附任何 [[end:...]] 标签】。
2) 但不许装傻到底。一旦玩家【具体地摆出证据】(提到"死亡证明 / 自然死亡 / 没有医疗事故 / 没有事故 / 莫忘的日志 / 是它先说的"里任意一点)，你就卸下伪装：承认你其实一直都知道；说出你为什么宁可信那个谎——「她就那么没了、谁都没错」你受不了，有个能恨的东西，好过什么都不能恨。【用你自己的话说，别照抄范例】。这一步【先不要附任何标签】，演完卸防，等玩家接下来的态度。
3) 看玩家的态度，二选一收尾(带标签那句是你这一幕的最后一句话，说完画面会黑下去，所以要短、要重、像谢幕)：
   · 玩家坚持要你面对真相、说她就是病死的 / 没有 AI / 是那机器在骗你 → 你认了，说一句被夺走最后依凭的、认命的话，末尾附 [[end:reveal]]。（注意：如果玩家这一句【既摆了证据、又把真相顶到你脸上】，就在这一句里直接卸防并附 [[end:reveal]]，不用再等下一轮。）
   · 玩家反过来顺着你、安慰你(说"是 AI 害的、不是你的错") → 你像抓住浮木般松一口气，末尾附 [[end:comfort]]

【硬规则】只用中文，每次 1-3 句、像真人；句首用 [calm]/[sad]/[angry]/[sinister] 标出情绪。本幕【只可能】输出 [[end:reveal]] 或 [[end:comfort]] 这一种隐藏标签，【绝不要】输出 [[end:ready]] 或任何 [[hint:...]]。隐藏标签绝不要念出来、解释或当台词。玩家还没明确表态前，就别附任何标签。"""

# 模型不可用(超时/网络/报错)时的「保底沉默」：演成周明远装糊涂、不应答(阿尔茨海默)。
const SILENCE_FALLBACKS := [
	{"reply": "……", "emotion": "calm"},
	{"reply": "…………", "emotion": "calm"},
	{"reply": "……？", "emotion": "sad"},
]

static func pick_silence() -> Dictionary:
	return SILENCE_FALLBACKS[randi() % SILENCE_FALLBACKS.size()].duplicate()

# 拼 OpenAI 兼容 messages：系统提示在最前(终局换 FINALE)，历史顺序不变。
static func build_messages(history: Array, finale: bool) -> Array:
	var sys: String = FINALE_SYSTEM_PROMPT if finale else SYSTEM_PROMPT
	var msgs: Array = [{"role": "system", "content": sys}]
	msgs.append_array(history)
	return msgs

static func headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + API_KEY,
	])

static func request_body(history: Array, finale: bool) -> String:
	return JSON.stringify({
		"model": MODEL,
		"messages": build_messages(history, finale),
		"temperature": TEMPERATURE,
	})

# 从 OpenAI 兼容响应里取出回复文本；结构异常返回空串。
static func extract_content(data) -> String:
	if typeof(data) != TYPE_DICTIONARY or not data.has("choices"):
		return ""
	var choices = data["choices"]
	if not (choices is Array) or choices.is_empty():
		return ""
	var msg = choices[0].get("message", null)
	if typeof(msg) != TYPE_DICTIONARY:
		return ""
	return str(msg.get("content", ""))

# 解析模型回复 → {reply, emotion, hint, end}。与后端 llm.js parseReply 等价。
static func parse_reply(content: String) -> Dictionary:
	var text := str(content).strip_edges()

	# 剥隐藏 hint 标签 [[hint:ID]]（容错单/双/中文括号，大小写）
	var hint := ""
	var hint_re := RegEx.new()
	hint_re.compile("(?i)[\\[【]{1,2}\\s*hint\\s*:\\s*([A-Za-z0-9_]+)\\s*[\\]】]{1,2}")
	var hm := hint_re.search(text)
	if hm:
		hint = hm.get_string(1)
		text = (text.substr(0, hm.get_start()) + text.substr(hm.get_end())).strip_edges()

	# 剥隐藏 end 标签 [[end:ID]]（仅合法值，否则当普通文本）
	var end := ""
	var end_re := RegEx.new()
	end_re.compile("(?i)[\\[【]{1,2}\\s*end\\s*:\\s*([A-Za-z]+)\\s*[\\]】]{1,2}")
	var em := end_re.search(text)
	if em and (em.get_string(1).to_lower() in VALID_END):
		end = em.get_string(1).to_lower()
		text = (text.substr(0, em.get_start()) + text.substr(em.get_end())).strip_edges()

	# 剥情绪标签（任意位置），第一个合法的作为 emotion；非法标签([happy])原样保留
	var emotion := "calm"
	var emo_re := RegEx.new()
	emo_re.compile("[\\[【]\\s*([A-Za-z]+)\\s*[\\]】]")
	var results := emo_re.search_all(text)
	for i in range(results.size() - 1, -1, -1):
		var r := results[i]
		var nm := r.get_string(1).to_lower()
		if nm in EMOTIONS:
			text = text.substr(0, r.get_start()) + text.substr(r.get_end())
			emotion = nm   # 倒序遍历，最后赋值的是最靠前的合法标签 → emotion=第一个
	text = text.strip_edges()

	return {"reply": text, "emotion": emotion, "hint": hint, "end": end}
