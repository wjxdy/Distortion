import { test } from "node:test";
import assert from "node:assert/strict";
import { buildMessages } from "../src/llm.js";
import { SYSTEM_PROMPT } from "../src/oldman.js";

test("空历史时只含 system 提示", () => {
  const msgs = buildMessages([]);
  assert.deepEqual(msgs, [{ role: "system", content: SYSTEM_PROMPT }]);
});

test("把历史接在 system 之后，顺序不变", () => {
  const history = [
    { role: "user", content: "你有家人吗？" },
    { role: "assistant", content: "我一个人。" },
  ];
  const msgs = buildMessages(history);
  assert.equal(msgs.length, 3);
  assert.equal(msgs[0].role, "system");
  assert.deepEqual(msgs.slice(1), history);
});
