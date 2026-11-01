const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

test('OCS requests use the compatible API and return expected responses', { timeout: 20000 }, async t => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ocs-test-'));
  let calls = 0;
  const mock = http.createServer(async (req, res) => {
    let body = '';
    for await (const chunk of req) body += chunk;
    const input = JSON.parse(body);
    assert.equal(req.url, '/v1/chat/completions');
    assert.equal(req.headers.authorization, 'Bearer local-test-only');
    assert.equal(input.model, 'deepseek-chat');
    calls++;
    res.setHeader('Content-Type', 'application/json');
    if (input.messages[1].content.includes('upstream-error')) {
      res.writeHead(503);
      res.end(JSON.stringify({ error: 'mock unavailable' }));
      return;
    }
    const answers = { single: 'B', multiple: 'A#C', judgement: '正确', completion: '2#4' };
    const answer = Object.entries(answers).find(([type]) => input.messages[1].content.includes('test-' + type))?.[1];
    res.end(JSON.stringify({ choices: [{ message: { content: answer || '2' } }] }));
  });
  await listen(mock);
  const portProbe = http.createServer();
  await listen(portProbe);
  const port = portProbe.address().port;
  await new Promise(resolve => portProbe.close(resolve));
  const child = spawn(process.execPath, [path.resolve(__dirname, '../server.js')], {
    cwd: tempDir,
    env: {
      ...process.env, OCS_PORT: String(port), OCS_AI_PROVIDER: 'deepseek', OCS_DEBUG: 'false',
      DEEPSEEK_ENABLED: 'true', DEEPSEEK_API_KEY: 'local-test-only', DEEPSEEK_MODEL: 'deepseek-chat',
      DEEPSEEK_BASE_URL: 'http://127.0.0.1:' + mock.address().port + '/v1', OCS_DATA_DIR: tempDir
    }, stdio: ['ignore', 'pipe', 'pipe']
  });
  let output = '';
  child.stderr.on('data', chunk => output += chunk);
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) {
      const exited = new Promise(resolve => child.once('exit', resolve));
      child.kill();
      await exited;
    }
    await new Promise(resolve => mock.close(resolve));
    fs.rmSync(tempDir, { recursive: true, force: true });
  });
  const base = 'http://127.0.0.1:' + port;
  let ready = false;
  for (let i = 0; i < 100; i++) {
    if (child.exitCode !== null) throw new Error('Server exited: ' + output);
    try { const status = await fetch(base); ready = status.ok; if (ready) break; } catch {}
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  assert.ok(ready, 'Local server starts');
  const info = await (await fetch(base + '/info')).json();
  assert.equal(info.provider, 'deepseek');
  assert.ok(!JSON.stringify(info).includes('local-test-only'));
  assert.equal((await (await fetch(base + '/search')).json()).code, 0);
  for (const [type, expected] of Object.entries({ single: 'B', multiple: 'A#C', judgement: '正确', completion: '2#4' })) {
    const title = 'test-' + type;
    const result = await (await fetch(base + '/search', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, type, options: 'A.1\nB.2\nC.3' })
    })).json();
    assert.deepEqual(result, { code: 1, question: title, answer: expected });
  }
  const error = await (await fetch(base + '/search?title=upstream-error')).json();
  assert.equal(error.code, 0);
  assert.match(error.msg, /503/);
  assert.equal(calls, 5);
});
