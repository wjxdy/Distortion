import { test } from "node:test";
import assert from "node:assert/strict";
import { retryAsync } from "../src/retry.js";

const noSleep = async () => {};

test("第一次就成功：只调用一次", async () => {
  let calls = 0;
  const r = await retryAsync(async () => { calls++; return "ok"; }, { tries: 3, sleep: noSleep });
  assert.equal(r, "ok");
  assert.equal(calls, 1);
});

test("前两次可重试失败、第三次成功：重试到成功", async () => {
  let calls = 0;
  const fn = async () => {
    calls++;
    if (calls < 3) { const e = new Error("overload"); e.retryable = true; throw e; }
    return "ok";
  };
  const r = await retryAsync(fn, { tries: 5, shouldRetry: (e) => e.retryable, sleep: noSleep });
  assert.equal(r, "ok");
  assert.equal(calls, 3);
});

test("不可重试的错误立即抛出：只调用一次", async () => {
  let calls = 0;
  const fn = async () => { calls++; const e = new Error("auth"); e.retryable = false; throw e; };
  await assert.rejects(
    () => retryAsync(fn, { tries: 5, shouldRetry: (e) => e.retryable, sleep: noSleep }),
    /auth/
  );
  assert.equal(calls, 1);
});

test("重试耗尽仍失败：抛最后一个错误", async () => {
  let calls = 0;
  const fn = async () => { calls++; const e = new Error("overload"); e.retryable = true; throw e; };
  await assert.rejects(
    () => retryAsync(fn, { tries: 3, shouldRetry: () => true, sleep: noSleep }),
    /overload/
  );
  assert.equal(calls, 3);
});
