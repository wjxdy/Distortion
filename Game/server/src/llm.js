import { SYSTEM_PROMPT } from "./oldman.js";
import { retryAsync } from "./retry.js";

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
export async function callKimi(history) {
  const baseUrl = process.env.KIMI_BASE_URL || "https://api.moonshot.cn/v1";
  const apiKey = process.env.KIMI_API_KEY;
  const model = process.env.KIMI_MODEL || "kimi-k2.6";
  // kimi-k2.6 等推理模型只接受 temperature=1；默认 1，可用 KIMI_TEMPERATURE 覆盖。
  const temperature = Number(process.env.KIMI_TEMPERATURE ?? 1);
  if (!apiKey) throw new Error("缺少环境变量 KIMI_API_KEY");

  // 月之暗面间歇性 429（引擎过载）/ 5xx 时自动重试，避免现场演示翻车。
  return retryAsync(
    async () => {
      const res = await fetch(`${baseUrl}/chat/completions`, {
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
      });
      if (!res.ok) {
        const err = new Error(`模型调用失败 ${res.status}: ${await res.text()}`);
        err.retryable = res.status === 429 || res.status >= 500;
        throw err;
      }
      return extractReply(await res.json());
    },
    { tries: 4, sleepMs: 1200, shouldRetry: (e) => e.retryable }
  );
}
