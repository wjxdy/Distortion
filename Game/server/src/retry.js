const defaultSleep = (ms) => new Promise((r) => setTimeout(r, ms));

// 通用异步重试：fn 失败且 shouldRetry(err) 为真时，最多重试到 tries 次，每次间隔 sleepMs。
export async function retryAsync(
  fn,
  { tries = 3, sleepMs = 800, shouldRetry = () => true, sleep = defaultSleep } = {}
) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (i === tries - 1 || !shouldRetry(e)) throw e;
      await sleep(sleepMs);
    }
  }
  throw lastErr;
}
