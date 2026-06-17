import { SYSTEM_PROMPT, pickSilence } from "./oldman.js";
import { retryAsync } from "./retry.js";

// 调模型的健壮性参数（可按现场情况调）：
// 总尝试次数=1次初试+1次重试。瞬时抖动重试1次基本能救回；持续过载则尽快保底沉默，
// 不让玩家干等(全过载时约 2×超时 ≈ 12s 出"……")。想多重试可调大，但过载时等待会变长。
const TRIES = 2;
const RETRY_SLEEP_MS = 500; // 每次重试间隔
const REQUEST_TIMEOUT_MS = 6000; // 单次请求超时；超过即放弃这次、计为可重试失败

// 调模型失败(过载/超时/网络/重试耗尽)时，不抛错给玩家，而是返回周明远的「沉默」保底，
// 让前端永远有回应、不卡死。真实错误打到服务器日志便于排查。
export async function withSilenceFallback(fn) {
  try {
    return await fn();
  } catch (e) {
    console.error("[周明远·保底沉默] 模型不可用:", e?.message || e);
    return pickSilence();
  }
}

// 把对话历史拼成 OpenAI 兼容的 messages：system 提示在最前，历史顺序不变。
export function buildMessages(history) {
  return [{ role: "system", content: SYSTEM_PROMPT }, ...history];
}

const EMOTIONS = new Set(["calm", "angry", "sinister", "sad"]);

// 解析句首情绪标签 [calm]/[sad]/[angry]/[sinister]（兼容中文【】、大小写），
// 拆成 { reply, emotion }。无标签或非法标签时 emotion 兜底 "calm"。
export function parseReply(content) {
  let text = String(content).trim();
  let emotion = "calm";
  const m = text.match(/^[\[【]\s*([a-zA-Z]+)\s*[\]】]\s*/);
  if (m && EMOTIONS.has(m[1].toLowerCase())) {
    emotion = m[1].toLowerCase();
    text = text.slice(m[0].length).trim();
  }
  return { reply: text, emotion };
}

// 从 OpenAI 兼容的响应里取出模型回复，返回 { reply, emotion }。结构异常则抛错。
export function extractReply(apiJson) {
  const content = apiJson?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw new Error("无法解析模型响应");
  return parseReply(content);
}

// 真实调用月之暗面 Kimi（OpenAI 兼容接口）：传入对话历史，返回老人的下一句回复。
// 默认模型用非推理的 moonshot-v1-32k（快，~1s）；可用 KIMI_MODEL 覆盖。
// 过载/超时/网络失败重试 TRIES 次后仍不行 → 返回周明远「沉默」保底，绝不把错误抛给玩家。
export async function callKimi(history) {
  const baseUrl = process.env.KIMI_BASE_URL || "https://api.moonshot.cn/v1";
  const apiKey = process.env.KIMI_API_KEY;
  const model = process.env.KIMI_MODEL || "moonshot-v1-32k";
  // v1 系可自由设温度；0.6 兼顾角色稳定与个性。(注：kimi-k2.x 推理模型只接受 1)
  const temperature = Number(process.env.KIMI_TEMPERATURE ?? 0.6);
  // 缺 key 属配置错误：硬报，不伪装成"沉默"，免得掩盖问题。
  if (!apiKey) throw new Error("缺少环境变量 KIMI_API_KEY");

  const callOnce = async () => {
    // 单次请求超时：过载时月之暗面会挂很久才 429，超时主动放弃、计为可重试失败。
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), REQUEST_TIMEOUT_MS);
    let res;
    try {
      res = await fetch(`${baseUrl}/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: buildMessages(history),
          temperature,
        }),
        signal: ctrl.signal,
      });
    } catch (e) {
      // 超时(AbortError)或网络错误：都按可重试处理。
      const err = new Error(
        e?.name === "AbortError"
          ? `模型调用超时(${REQUEST_TIMEOUT_MS}ms)`
          : `网络错误: ${e?.message || e}`
      );
      err.retryable = true;
      throw err;
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) {
      const err = new Error(`模型调用失败 ${res.status}: ${await res.text()}`);
      err.retryable = res.status === 429 || res.status >= 500;
      throw err;
    }
    return extractReply(await res.json());
  };

  // 月之暗面间歇性 429（引擎过载）/ 5xx / 超时 时自动重试；都失败则保底沉默。
  return withSilenceFallback(() =>
    retryAsync(callOnce, {
      tries: TRIES,
      sleepMs: RETRY_SLEEP_MS,
      shouldRetry: (e) => e.retryable,
    })
  );
}
