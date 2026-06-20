// EdgeOne Edge 函数(V8 运行时)：POST /api/chat —— 把游戏(网页版)发来的
// OpenAI 格式请求体原样转发给 Moonshot/Kimi，并在服务端注入 Authorization
// (key 永不下发到前端)。
//
// 为什么用 Edge 函数而非 Node 云函数：本代理只做一次 fetch 转发，V8 边缘运行时
// 原生支持 fetch、免构建/免 npm，部署更稳、延迟更低。
// ⚠️ V8 运行时没有 Response.json()，统一用 new Response(JSON.stringify(...))。
//
// 为什么需要它：Godot 网页版若直连 api.moonshot.cn 会(1)被浏览器 CORS 拦、
// (2)把 key 暴露在前端包里。改走同源 /api/chat 两个问题一起解决。客户端已自行
// 拼好完整请求体，这里只透明转发，五种调用(审讯/终端/裁判/电话/称号)全复用。
//
// 配置：EdgeOne Pages 控制台 → 本项目 → 环境变量 MOONSHOT_API_KEY。

const UPSTREAM = "https://api.moonshot.cn/v1/chat/completions";
const JSON_HEADERS = { "Content-Type": "application/json" };

export async function onRequestPost(context) {
  const key = context.env && context.env.MOONSHOT_API_KEY;
  if (!key) {
    return new Response(
      JSON.stringify({ error: "服务端未配置 MOONSHOT_API_KEY 环境变量" }),
      { status: 500, headers: JSON_HEADERS }
    );
  }

  // 原样取客户端请求体(已是合法 OpenAI 请求)，整体转发。
  const body = await context.request.text();

  let upstream;
  try {
    upstream = await fetch(UPSTREAM, {
      method: "POST",
      headers: { ...JSON_HEADERS, Authorization: "Bearer " + key },
      body,
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "转发上游失败: " + String((e && e.message) || e) }),
      { status: 502, headers: JSON_HEADERS }
    );
  }

  // 把上游响应(状态码 + JSON 正文)原样回给客户端，由游戏自己解析。
  const text = await upstream.text();
  return new Response(text, { status: upstream.status, headers: JSON_HEADERS });
}

// 健康检查：GET /api/chat → 确认代理已部署(不触碰 key)。
export function onRequestGet() {
  return new Response(
    JSON.stringify({ ok: true, service: "distortion-llm-proxy" }),
    { headers: JSON_HEADERS }
  );
}
