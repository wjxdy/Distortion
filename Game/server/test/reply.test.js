import { test } from "node:test";
import assert from "node:assert/strict";
import { extractReply } from "../src/llm.js";

test("从 OpenAI 兼容响应里取出回复并去除首尾空白", () => {
  const apiJson = { choices: [{ message: { content: "  我一个人过了一辈子。  " } }] };
  assert.equal(extractReply(apiJson), "我一个人过了一辈子。");
});

test("响应结构异常时抛出明确错误", () => {
  assert.throws(() => extractReply({}), /无法解析模型响应/);
});
