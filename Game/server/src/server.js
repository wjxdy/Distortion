import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { callKimi } from "./llm.js";

// 极简 .env 加载（零依赖）：从 server/.env 读取，不覆盖已存在的环境变量。
(function loadEnv() {
  try {
    const path = new URL("../.env", import.meta.url);
    for (const line of readFileSync(path, "utf8").split("\n")) {
      const m = line.match(/^\s*([\w.-]+)\s*=\s*(.*)\s*$/);
      if (m && !process.env[m[1]]) {
        process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
      }
    }
  } catch {
    /* 没有 .env 也无妨，靠真实环境变量 */
  }
})();

const PORT = process.env.PORT || 8787;

// 允许跨域，方便 Godot 网页(HTML5)版调用。
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const server = createServer((req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, CORS);
    res.end();
    return;
  }

  if (req.method === "POST" && req.url === "/chat") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", async () => {
      try {
        const { history, finale } = JSON.parse(body || "{}");
        const result = await callKimi(Array.isArray(history) ? history : [], Boolean(finale));
        res.writeHead(200, { ...CORS, "Content-Type": "application/json" });
        res.end(JSON.stringify(result)); // { reply, emotion, hint, end }
      } catch (e) {
        res.writeHead(500, { ...CORS, "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: String(e?.message || e) }));
      }
    });
    return;
  }

  res.writeHead(404, CORS);
  res.end();
});

// 默认只绑 127.0.0.1：本地开发够用，生产经 nginx 反代、不对公网暴露 8787(更安全)。
// 需要对外直连时设 HOST=0.0.0.0。
const HOST = process.env.HOST || "127.0.0.1";
server.listen(PORT, HOST, () => {
  console.log(`《失真》后端已启动: http://${HOST}:${PORT}  (POST /chat)`);
});
