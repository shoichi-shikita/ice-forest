import test from 'node:test';
import assert from 'node:assert/strict';
import { run } from './dispatch.mjs';

const env = { AUTOMATION_ENABLED: 'true', GITHUB_REPOSITORY: 'owner/ice-forest', ISSUE_NUMBER: '1', GITHUB_ACTOR: 'owner', GITHUB_TOKEN: 'fake-gh', JULES_API_KEY: 'fake-jules' };
function mock(options = {}) {
  const calls = [];
  const request = async (url, init) => {
    const body = init.body && JSON.parse(init.body);
    calls.push({ url, ...init, body });
    let data;
    if (url.endsWith('/repos/owner/ice-forest')) data = { full_name: env.GITHUB_REPOSITORY, private: !!options.private, visibility: options.private ? 'private' : 'public', default_branch: 'main' };
    else if (url.endsWith('/permission')) data = { permission: options.permission ?? 'write' };
    else if (url.endsWith('/issues/1')) data = { state: 'open', title: '森の入口', body: '足音を追加', labels: options.noLabel ? [] : [{ name: 'ai-ready' }] };
    else if (url.includes('/comments?')) data = options.duplicate ? [{ user: { login: 'github-actions[bot]' }, body: '<!-- ice-forest-jules-v1 -->' }] : [];
    else if (url.includes('/sources?')) data = { sources: options.noSource ? [] : [{ name: 'sources/github/owner/ice-forest', githubRepo: { owner: 'owner', repo: 'ice-forest' } }] };
    else if (url.endsWith('/issues/1/comments')) data = { id: 42 };
    else if (url.endsWith('/sessions')) {
      if (options.timeout) throw Error('timeout');
      data = { name: 'sessions/123' };
    } else if (url.endsWith('/issues/comments/42')) data = {};
    else throw Error('Unexpected request');
    return { ok: true, status: 200, json: async () => data };
  };
  return { request, calls };
}
test('disabled and invalid inputs make zero requests', async () => {
  for (const override of [{ AUTOMATION_ENABLED: '' }, { ISSUE_NUMBER: '1; echo injected' }, { GITHUB_REPOSITORY: '../bad' }, { JULES_API_KEY: '' }]) {
    const m = mock(); await assert.rejects(run({ ...env, ...override }, m.request)); assert.equal(m.calls.length, 0);
  }
});
for (const [name, options] of Object.entries({ private: { private: true }, outsider: { permission: 'read' }, unlabelled: { noLabel: true }, disconnected: { noSource: true } })) {
  test(`${name} cannot create a session`, async () => {
    const m = mock(options); await assert.rejects(run(env, m.request)); assert.equal(m.calls.filter(c => c.method === 'POST').length, 0);
  });
}
test('duplicate dispatch is ignored', async () => {
  const m = mock({ duplicate: true }); assert.equal((await run(env, m.request)).status, 'already-dispatched');
  assert.equal(m.calls.filter(c => c.method === 'POST').length, 0);
});
test('one session, durable intent first, approval required, branch discovered', async () => {
  const m = mock(); assert.equal((await run(env, m.request)).status, 'created');
  const posts = m.calls.filter(c => c.method === 'POST'); assert.equal(posts.length, 2);
  assert.match(posts[0].url, /comments$/); assert.match(posts[1].url, /sessions$/);
  assert.equal(posts[1].body.requirePlanApproval, true);
  assert.equal(posts[1].body.sourceContext.githubRepoContext.startingBranch, 'main');
  assert.equal(posts[1].body.automationMode, 'AUTO_CREATE_PR');
  assert.ok(m.calls.every(c => c.redirect === 'error'));
  assert.ok(m.calls.every(c => !c.url.includes('openai') && !c.url.includes('generativelanguage')));
});
test('ambiguous timeout is never retried', async () => {
  const m = mock({ timeout: true }); await assert.rejects(run(env, m.request), /timeout/);
  assert.equal(m.calls.filter(c => c.url.endsWith('/sessions')).length, 1);
  assert.ok(m.calls.some(c => c.url.endsWith('/comments') && c.body.body.includes('ice-forest-jules-v1')));
});
test('HTTP failures do not disclose response bodies', async () => {
  await assert.rejects(run(env, async () => ({ ok: false, status: 429, json: () => { throw Error('secret'); } })), /429.*no automatic retry/);
});
