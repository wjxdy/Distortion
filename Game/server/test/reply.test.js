import { test } from "node:test";
import assert from "node:assert/strict";
import { extractReply, parseReply } from "../src/llm.js";

test("解析句首情绪标签，返回 {reply, emotion} 并去空白", () => {
  const apiJson = { choices: [{ message: { content: "[sad] 她……只是出门买点菜。 " } }] };
  assert.deepEqual(extractReply(apiJson), { reply: "她……只是出门买点菜。", emotion: "sad", hint: "", end: "" });
});

test("无情绪标签时 emotion 兜底 calm", () => {
  const apiJson = { choices: [{ message: { content: "  我一个人过了一辈子。  " } }] };
  assert.deepEqual(extractReply(apiJson), { reply: "我一个人过了一辈子。", emotion: "calm", hint: "", end: "" });
});

test("兼容中文方括号【】与大小写", () => {
  assert.deepEqual(parseReply("【ANGRY】是 AI 害死了她！"), { reply: "是 AI 害死了她！", emotion: "angry", hint: "", end: "" });
});

test("非法标签按普通文本处理，不当成情绪", () => {
  assert.deepEqual(parseReply("[happy]你好"), { reply: "[happy]你好", emotion: "calm", hint: "", end: "" });
});

test("响应结构异常时抛出明确错误", () => {
  assert.throws(() => extractReply({}), /无法解析模型响应/);
});

test("解析末尾的隐藏提醒标签 [[hint:ID]]，剥离并返回 hint", () => {
  const r = parseReply("[angry]是 AI 害死她的！[[hint:investigate_death]]");
  assert.equal(r.reply, "是 AI 害死她的！");
  assert.equal(r.emotion, "angry");
  assert.equal(r.hint, "investigate_death");
});

test("无提醒标签时 hint 为空字符串", () => {
  const r = parseReply("[calm]我一个人过。");
  assert.equal(r.reply, "我一个人过。");
  assert.equal(r.hint, "");
});

test("提醒标签前后空白都清掉，不残留在回复里", () => {
  const r = parseReply("我就……记记日常。   [[hint:protecting_app]]");
  assert.equal(r.reply, "我就……记记日常。");
  assert.equal(r.hint, "protecting_app");
});

test("模型只写单括号 [hint:ID] 也要剥掉，绝不漏进台词", () => {
  const r = parseReply("我记得用手机里的莫忘记事的。[hint:protecting_app]");
  assert.equal(r.reply, "我记得用手机里的莫忘记事的。");
  assert.equal(r.hint, "protecting_app");
});

test("中文方括号【hint:ID】也能剥掉", () => {
  const r = parseReply("是 AI 害死她的！【hint:investigate_death】");
  assert.equal(r.reply, "是 AI 害死她的！");
  assert.equal(r.hint, "investigate_death");
});

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
