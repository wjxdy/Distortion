import { test } from "node:test";
import assert from "node:assert/strict";
import { withSilenceFallback } from "../src/llm.js";
import { SILENCE_FALLBACKS, pickSilence } from "../src/oldman.js";

test("pickSilence 返回合法的沉默保底（含 reply 与 emotion）", () => {
  const s = pickSilence();
  assert.ok(SILENCE_FALLBACKS.some((f) => f.reply === s.reply && f.emotion === s.emotion));
  assert.equal(typeof s.reply, "string");
  assert.ok(s.reply.length > 0);
});

test("withSilenceFallback：成功时原样返回模型结果", async () => {
  const ok = { reply: "你好", emotion: "calm" };
  const r = await withSilenceFallback(async () => ok);
  assert.deepEqual(r, ok);
});

test("withSilenceFallback：失败时返回沉默保底（不抛错）", async () => {
  const origErr = console.error;
  console.error = () => {}; // 屏蔽预期内的错误日志，保持测试输出干净
  try {
    const r = await withSilenceFallback(async () => {
      const e = new Error("overload");
      e.retryable = true;
      throw e;
    });
    assert.ok(SILENCE_FALLBACKS.some((f) => f.reply === r.reply && f.emotion === r.emotion));
  } finally {
    console.error = origErr;
  }
});
