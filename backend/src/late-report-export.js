import { Worker } from 'node:worker_threads';

let running = 0;
// File formatting never runs on the HTTP event loop or the Flutter UI thread.
export function renderLateReport(payload, { timeoutMs = 30000 } = {}) {
  if (running >= 2) return Promise.reject(new Error('Report export service is busy.'));
  running++;
  return new Promise((resolve, reject) => {
    let worker;
    let timer;
    let finished = false;
    const finish = (error, bytes) => {
      if (finished) return;
      finished = true;
      clearTimeout(timer);
      running--;
      if (worker) void worker.terminate();
      if (error) reject(error); else resolve(Buffer.from(bytes));
    };
    try {
      worker = new Worker(new URL('./late-report-export-worker.js', import.meta.url), {
        workerData: payload, resourceLimits: { maxOldGenerationSizeMb: 256 },
      });
      timer = setTimeout(() => finish(new Error('Report export timed out.')), timeoutMs);
      worker.once('message', result => result.error
        ? finish(new Error(result.error)) : finish(null, result.bytes));
      worker.once('error', finish);
      worker.once('exit', () => finish(new Error('Report export worker stopped.')));
    } catch (error) { finish(error); }
  });
}
