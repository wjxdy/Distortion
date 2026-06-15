# 剧情数据：真相表 + 探索动作 + 结尾。改剧情只动这里，逻辑不变。
extends RefCounted

const TRUTHS := [
	{
		"id": "wife",
		"required_key": "linxiulan",
		"keywords": ["林秀兰", "妻子", "老婆", "爱人", "蓝裙", "红烧肉", "她是谁", "结婚"],
		"fragment": "真相碎片：林秀兰，他的妻子。2021 年，因病去世。——不是 AI。"
	}
]

const EXPLORE_ACTIONS := [
	{
		"id": "archive",
		"label": "查阅周明远自制 AI 的记忆档案残片",
		"grants_key": "linxiulan",
		"text": "档案残片《2019.5.20》：「妻子 林秀兰 · 生日 · 那条蓝裙子」。病毒没能完全覆盖这一条。"
	}
]

const ENDING := "一块被改写的记忆裂开了。可你忽然意识到——这已经是这个月第三个了。（待续）"
