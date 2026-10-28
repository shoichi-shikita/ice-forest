// One fixed, documentation-only integration task. No arbitrary prompts or paid APIs.
const repo = 'shoichi-shikita/ice-forest';
const issue = `/repos/${repo}/issues/2/comments`;
const marker = '<!-- ice-forest-e2e-v1 -->';
async function api(service, path, method = 'GET', body) {
  const github = service === 'github';
  const response = await fetch((github ? 'https://api.github.com' : 'https://jules.googleapis.com/v1alpha') + path, {
    method, redirect: 'error', signal: AbortSignal.timeout(20000),
    headers: { 'Content-Type': 'application/json', ...(github ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json' } : { 'X-Goog-Api-Key': process.env.JULES_API_KEY }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (!response.ok) throw Error(`${service} HTTP ${response.status}; not automatically retried`);
  return response.status === 204 ? {} : response.json();
}
if (process.env.AUTOMATION_ENABLED !== 'true' || process.env.GITHUB_REPOSITORY !== repo || !process.env.JULES_API_KEY || !process.env.GITHUB_TOKEN) throw Error('Disabled or missing configuration');
const metadata = await api('github', `/repos/${repo}`);
if (metadata.private !== false || metadata.visibility !== 'public') throw Error('Public repository required');
let comments = [];
for (let page = 1; page <= 20; page++) {
  const batch = await api('github', `${issue}?per_page=100&page=${page}`);
  comments.push(...batch);
  if (batch.length < 100) break;
  if (page === 20) throw Error('Comment pagination limit');
}
let comment = comments.find(c => c.user?.login === 'github-actions[bot]' && c.body?.includes(marker));
let name = comment?.body.match(/sessions\/[A-Za-z0-9_-]+/)?.[0];
if (comment && !name) throw Error('Previous creation ambiguous; inspect Jules before retrying');
if (!comment) {
  let next = '', source;
  for (let page = 0; page < 20; page++) {
    const data = await api('jules', '/sources?pageSize=100' + (next ? '&pageToken=' + encodeURIComponent(next) : ''));
    source = data.sources?.find(s => `${s.githubRepo?.owner}/${s.githubRepo?.repo}` === repo);
    if (source || !data.nextPageToken) break;
    next = data.nextPageToken;
  }
  if (!source) throw Error('Jules source not found');
  comment = await api('github', issue, 'POST', { body: marker + '\nStarting one documentation-only Jules session. Do not retry ambiguous creation.' });
  const session = await api('jules', '/sessions', 'POST', {
    title: 'Ice Forest integration verification #2',
    sourceContext: { source: source.name, githubRepoContext: { startingBranch: metadata.default_branch } },
    requirePlanApproval: false,
    automationMode: 'AUTO_CREATE_PR',
    prompt: 'Perform exactly one bounded documentation task. Read README.md and the automation files. Add only docs/development-workflow.md in Japanese describing the existing GitHub Issue/workflow_dispatch -> Jules -> PR -> Codex review flow, initial configuration, stopping on errors, duplicate prevention, included-plan limits, and manual merge. Explain that normal dispatch requires human plan approval. State that the game itself is not implemented and no game design is confirmed. Do not claim that full end-to-end verification has passed yet. Do not modify any other file, workflows, runtime code, settings, credentials, permissions, billing, or dependencies. Do not install software, use paid APIs, merge, or deploy. Open a non-draft PR referencing #2. The human has authorized this exact documentation task to execute without an extra plan approval. If unable, stop and report why.'
  });
  name = session.name;
  if (!/^sessions\/[A-Za-z0-9_-]+$/.test(name ?? '')) throw Error('Invalid session name');
}
const update = body => api('github', `/repos/${repo}/issues/comments/${comment.id}`, 'PATCH', { body: `${marker}\nSession: ${name}\n${body}` });
await update('Jules task created. Waiting for a pull request.');
for (let attempt = 0; attempt < 24; attempt++) {
  const session = await api('jules', '/' + name);
  const state = /^[A-Z_]+$/.test(session.state ?? '') ? session.state : 'UNKNOWN';
  const pr = session.outputs?.map(o => o.pullRequest?.url).find(url => /^https:\/\/github\.com\/shoichi-shikita\/ice-forest\/pull\/\d+$/.test(url ?? ''));
  console.log(JSON.stringify({ session: name, state, ...(pr ? { pr } : {}) }));
  if (pr) { await update(`State: ${state}\nPR: ${pr}\nAwaiting independent Codex review; no automatic merge.`); process.exit(0); }
  if (['FAILED', 'PAUSED', 'AWAITING_PLAN_APPROVAL', 'AWAITING_USER_FEEDBACK'].includes(state)) { await update(`Stopped: ${state}. Human inspection required.`); throw Error('Jules stopped: ' + state); }
  await new Promise(resolve => setTimeout(resolve, 30000));
}
await update('Observation window ended. Existing Jules task may still be running; rerun this check to resume observation, not create another session.');
throw Error('Observation window ended');