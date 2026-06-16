import { test } from "node:test";
import assert from "node:assert/strict";
import { extractReply, parseReply } from "../src/llm.js";

test("解析句首情绪标签，返回 {reply, emotion} 并去空白", () => {
  const apiJson = { choices: [{ message: { content: "[sad] 她……只是出门买点菜。 " } }] };
  assert.deepEqual(extractReply(apiJson), { reply: "她……只是出门买点菜。", emotion: "sad" });
});

test("无情绪标签时 emotion 兜底 calm", () => {
  const apiJson = { choices: [{ message: { content: "  我一个人过了一辈子。  " } }] };
  assert.deepEqual(extractReply(apiJson), { reply: "我一个人过了一辈子。", emotion: "calm" });
});

test("兼容中文方括号【】与大小写", () => {
  assert.deepEqual(parseReply("【ANGRY】是 AI 害死了她！"), { reply: "是 AI 害死了她！", emotion: "angry" });
});

test("非法标签按普通文本处理，不当成情绪", () => {
  assert.deepEqual(parseReply("[happy]你好"), { reply: "[happy]你好", emotion: "calm" });
});

test("响应结构异常时抛出明确错误", () => {
  assert.throws(() => extractReply({}), /无法解析模型响应/);
});
