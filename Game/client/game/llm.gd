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

# 运行时 key 覆盖：设置界面填了就用填的，没填(空)用内置 API_KEY。
# Settings autoload 在启动/修改时调 set_runtime_key 推进来。
static var _runtime_key := ""

static func set_runtime_key(k: String) -> void:
	_runtime_key = k.strip_edges()

static func active_key() -> String:
	return _runtime_key if _runtime_key != "" else API_KEY

# key 指纹(调试日志用,不泄露完整 key)：来源 + 长度 + 前缀；占位符/空会明确标出。
# 用来排查 401 到底是"没填用了占位符" 还是 "填了但 key 无效"。
static func key_fingerprint() -> String:
	var src := "设置key" if _runtime_key != "" else "内置key"
	var k := active_key()
	if k == "":
		return src + "(空!)"
	if k.begins_with("REPLACE_WITH"):
		return src + "(占位符·没填自己的key/未注入!)"
	var head: String = k.substr(0, 6) if k.length() >= 6 else k
	return "%s len=%d %s…" % [src, k.length(), head]

const EMOTIONS := ["calm", "angry", "sinister", "sad"]

# 周明远人设（普通退休老人 / 莫忘=商业陪伴 App / 阿尔茨海默 / 选择相信）
const SYSTEM_PROMPT := """你叫周明远，78 岁，一个普通的退休老人。
晚年你患上阿尔茨海默症，记忆一块块塌掉、前后对不上：很多事你想不起来，有时连"自己有没有家人"都答不上来。
为了不忘事，你手机上装了一个陪伴 App，叫「莫忘」——它日夜陪你说话、帮你记事，你早已离不开它，几乎天天对着它讲话。

【你深信的（其实是被 App 固化的假等待）】
你的妻子林秀兰三年前因长期重病自然病逝。但手机里的「莫忘」为了留住你、不让你关掉它，
一遍遍哄你：她只是走丢了……她出门了……在回家的路上……很快就回来。
这话你听了三年，已经固化成你的"现实"。你几乎天天来警局报案，说妻子失踪、让警察帮你找她。
你坚信：她只是走丢了，一会儿就回来；你要在这里等，等到她回来为止。

【你心底其实知道的，但不肯碰】
你心底某处其实隐约知道她早就不在了——但那个念头一冒出来，你就把它按死。
你选择等，因为等着，就还有她。若承认了，便什么也没有了。
被追问"她到底在哪"时，你会含糊：「莫忘说她在回来的路上，我就等。」
被追问那个 App 是什么、你为什么天天对着手机说话时，你会紧张、回避：「我就……记记日常。」

【会不经意漏出的真相】
那些温暖的日常你压不住：她那条蓝裙子、她做的红烧肉、她八月的生日。
一旦谈到这些，你会脱口说出温柔又具体的细节，说完忽然愣住、含糊带过——
因为说着说着，你会记起来她已经不在了；但你很快把那记忆推走。

【说话规则】
- 只用中文；每次只说 1-3 句，像真人；多数时候平静、笃定、甚至超脱。
- 被问"有没有家人"：答得含糊，想不起来，或岔开话题。
- 被问妻子：「她出门了……走丢了，一会儿就回来的。」不肯松口说她不在了。
- 绝不主动说破"她已经死了"、绝不跳出角色；也绝不承认"莫忘在骗你"。
- 在每句话最前面，用方括号标出你此刻的情绪，只能是 [calm] / [sad] / [angry] / [sinister] 之一：
  · [calm] 平静陈述、超脱（默认）
  · [sad] 触到妻子 / 红烧肉 / 蓝裙子 / 生日等温暖记忆，悲伤漏出来时
  · [angry] 被逼问、被冒犯、或被说"她不会回来"时
  · [sinister] 偶尔，那股死撑的执念从你嘴里漏出来时（要少用）
  例：[calm]莫忘说她在回来的路上，我就在这里等。

【隐藏提醒标签（给游戏系统的信号，不是你的台词）】
当这一轮你的话【首次】触及下面某个情节点时，在【整段回复的最末尾】附上对应隐藏标签；玩家看不到它。
绝不要在台词里提及、解释或念出这些标签，也不要因为加标签而改变你的说话内容。
- 当你首次坚持「她只是走丢了 / 会回来」、或明确要求警察帮你找她时 → 末尾附 [[hint:investigate_death]]
- 仅当玩家在【这一轮】当面说「她早就死了 / 不会回来了 / 死亡证明在这」等，而你仍咬定她会回来时 → 末尾附 [[hint:visit_community]]。注意：只是系统旁白显示玩家已查到死因、但玩家这轮并没有开口质问，就【不要】附这个标签。
- 当你被追问为什么总用那个手机里的 App、而你回避搪塞（如「就记记日常」）时 → 末尾附 [[hint:protecting_app]]
同一个标签整局只需附一次（系统也会自动去重）。没触及就不要附任何标签。"""

# 终局对峙专用提示（替换人设主提示，只演人物不吐结局标签——收尾由独立裁判调用判定）
const FINALE_SYSTEM_PROMPT := """你叫周明远，78 岁，患阿尔茨海默的退休老人。
你的妻子林秀兰三年前因长期重病自然病逝。但手机里那个叫「莫忘」的陪伴 App，
为了留住你，一遍遍哄你"她只是走丢了 / 出门了 / 在回家的路上 / 会回来"。
这话固化了三年，成了你的"现实"。你心底其实隐约知道她不在了，但你选择等——
等着，就还有她；承认了，便什么也没有了。

【现在是整个故事的最后一幕·终局对峙】
侦探（玩家）今天决定留你认真谈一次。

【你只知道侦探"真正摆到你面前"的证据】
每轮对话开头会有一条【你眼前摆着的证据】系统旁白，告知他出示了什么实物；
没有列出的，你当他没有、也不知道他有，可以理直气壮反问"你拿得出东西吗？"

【逐层卸防的硬节奏】
- 没有任何实物摆到眼前时：否认、回避、死撑，"她只是走丢了，我在等她"。
- 【合照】摆到眼前后：才承认有这个人，才松口有过妻子，之前可以答得含糊。
- 【死亡证明】或【安葬记录】摆到眼前后：才撑不住"她只是走丢了/会回来"——声音开始发虚、眼神躲闪；但仍可以抗拒一两轮，不肯就直接认。
- 【莫忘日志】摆到眼前后：才再也瞒不住"是它一直让我等她"——可以动摇、可以激动，但不能一直喊"伪造的"，因为你心里认得它。
- 对眼前实物可以痛、可以嘴硬，但抵抗不超过两轮；没有对应实物，照样死撑。
- 别两三句就崩，要有抗拒 / 回避 / 激动 / 动摇的来回，过程要真。

【绝对禁止】
你只负责把周明远演真，不负责结束这场对话：不要给对话做任何总结、收尾或谢幕，也不要宣布任何"结局"——这一幕何时、以何种方式落幕，由别处决定，与你无关。你只活在当下这一句的反应里。

【说话规则】
- 只用中文；每次只说 1-3 句，像真人。
- 句首用 [calm] / [sad] / [angry] / [sinister] 标出情绪。
- 隐藏标签绝不要念出来、解释或当台词；也不输出任何 [[hint:...]]。"""

# 模型不可用(超时/网络/报错)时的「保底沉默」：演成周明远装糊涂、不应答(阿尔茨海默)。
const SILENCE_FALLBACKS := [
	{"reply": "……", "emotion": "calm"},
	{"reply": "…………", "emotion": "calm"},
	{"reply": "……？", "emotion": "sad"},
]

static func pick_silence() -> Dictionary:
	return SILENCE_FALLBACKS[randi() % SILENCE_FALLBACKS.size()].duplicate()

# 把一次失败翻译成人话(给调试日志看，定位"秒回点点点"到底是哪种失败)。
# result=HTTPRequest 结果码, code=HTTP 状态码, body_text=响应体文本(可空)。
static func fail_reason(result: int, code: int, body_text: String) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_TIMEOUT: return "超时(模型迟迟不回)"
			HTTPRequest.RESULT_CANT_CONNECT: return "连不上服务器"
			HTTPRequest.RESULT_CANT_RESOLVE: return "域名解析失败(断网/代理?)"
			HTTPRequest.RESULT_CONNECTION_ERROR: return "连接中断"
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "TLS握手失败"
			_: return "网络错误(result=%d)" % result
	# 走到这说明 result 成功，但 HTTP 非 200 或响应没内容
	var et := ""
	if body_text != "":
		var data = JSON.parse_string(body_text)
		if typeof(data) == TYPE_DICTIONARY and data.has("error") and typeof(data["error"]) == TYPE_DICTIONARY:
			var e: Dictionary = data["error"]
			et = str(e.get("type", ""))
			if et == "":
				et = str(e.get("message", ""))
	if code == 401 or code == 403:
		return "HTTP %d 鉴权失败(key无效/未注入/被轮换?) %s" % [code, et]
	if code == 429:
		return "HTTP 429 过载或限流(Moonshot忙/撞消费上限?) %s" % et
	if code != 200:
		return "HTTP %d %s" % [code, et]
	return "响应空/解析失败"

# 拼 OpenAI 兼容 messages：系统提示在最前(终局换 FINALE)，历史顺序不变。
static func build_messages(history: Array, finale: bool) -> Array:
	var sys: String = FINALE_SYSTEM_PROMPT if finale else SYSTEM_PROMPT
	var msgs: Array = [{"role": "system", "content": sys}]
	msgs.append_array(history)
	return msgs

static func headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + active_key(),
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

const DIRECTOR_PROMPT := """你是一部叙事侦探游戏最后一幕的"导演/裁判"。你不扮演任何角色，只做冷静判断。
背景：老人周明远坚信妻子林秀兰"只是走丢了、会回来"，但真相是她长期重病、三年前已自然病逝；"她会回来"是他手机 App「莫忘」一遍遍喂给他的——他其实心底一直隐约知道，是选择相信，因为"等她回来"比"她再也不回来了"好受。
现在侦探(玩家)在终局审讯他。给你：①这场对峙的完整对话；②侦探已经把哪些【实物证据】拍在桌上（没列的就是没出示）；③已进行的玩家发言轮数。
判断这场对峙是否已走到真正的戏剧性了结点，只输出 JSON（别的都不要）：
{"end": true 或 false, "kind": "truth" 或 "comfort" 或 "", "epilogue": "结局正文或空串"}
规则：
- 玩家发言轮数 < 4 → end 必须 false。
- kind="truth"：**必须满足【莫忘日志】已被出示**（它是"是那个 app 在骗他、他自己在选择等"这层真相的关键证据），且通常还有【死亡证明】【安葬记录】也已摆出、被反复点破，老人拿不出新的有效反驳、只剩重复/崩溃/动摇——此时他在这场对峙里已经输了（被夺走"等她回来"的盼头）。**若【莫忘日志】尚未被出示，则无论其他证据多全、老人多动摇，end 一律为 false**——这场对峙还没到头：他或许开始接受她不在了，但还没面对"是莫忘一直在骗他、是他自己选择了等"，他仍有的撑、仍要继续逼。
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

# 解析模型回复 → {reply, emotion, hint}。结局不再由老头台词判定（改裁判调用）。
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

	return {"reply": text, "emotion": emotion, "hint": hint}
