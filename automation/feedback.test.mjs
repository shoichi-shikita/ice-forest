import test from 'node:test';
import assert from 'node:assert/strict';
import { decide, run } from './feedback.mjs';
import { readFileSync } from 'node:fs';

test('privileged workflow excludes PR-ref triggers and pins checkout to default branch', () => {
  const workflow = readFileSync(new URL('../.github/workflows/ai-feedback.yml', import.meta.url), 'utf8');
  assert.doesNotMatch(workflow, /^\s{2}pull_request(?:_review|_target)?:/m);
  assert.match(workflow, /ref: \$\{\{ github.event.repository.default_branch \}\}/);
});

const pr = { number: 3, state: 'open', draft: false, html_url: 'https://github.com/shoichi-shikita/ice-forest/pull/3', labels: [{ name: 'ai-auto-fix' }], head: { sha: 'abc', repo: { full_name: 'shoichi-shikita/ice-forest' } }, base: { repo: { full_name: 'shoichi-shikita/ice-forest' } } };
const summary = (sha = 'abc', findings = true, status = 'completed') => ({ user: { login: 'chatgpt-codex-connector[bot]' }, body: `<!-- codex-review-state:v1 ${JSON.stringify({code_review:{commit_sha:sha,has_any_findings:findings,status}})} -->` });
const record = (action, head) => ({ user: { login: 'github-actions[bot]' }, body: `<!-- ice-feedback-v1 action=${action} head=${head} -->` });
const green = [{ name: 'test', status: 'completed', conclusion: 'success' }];
test('current completed review findings receive one fix', () => assert.equal(decide(pr, [summary()], []).action, 'fix'));
test('no finding, running, malformed, or impersonated review is ignored', () => {
  for (const c of [summary('abc', false), summary('abc', true, 'running'), { user: {login:'chatgpt-codex-connector[bot]'}, body: '<!-- codex-review-state:v1 bad -->' }, {...summary(), user:{login:'outsider'}}]) assert.equal(decide(pr,[c],[]).action,'skip');
});
test('fork, draft and closed PRs are skipped', () => {
  for (const p of [{...pr,draft:true},{...pr,state:'closed'},{...pr,head:{...pr.head,repo:{full_name:'outsider/fork'}}}]) assert.equal(decide(p,[summary()],[]).action,'skip');
});
test('same head and lifetime fix ceiling block duplicates', () => {
  for (const records of [[record('fix','abc')],[record('fix','old1'),record('fix','old2')]]) assert.equal(decide(pr,[summary(),...records],[]).action,'skip');
});
test('new corrected head requires green tests before one re-review', () => {
  const comments=[summary('old'),record('fix','old')];
  assert.equal(decide(pr,comments,green).action,'review');
  assert.equal(decide(pr,comments,[]).action,'skip');
  assert.equal(decide(pr,comments,[...green,{status:'completed',conclusion:'failure'}]).action,'skip');
  assert.equal(decide(pr,[...comments,record('review','abc')],green).action,'skip');
});
const env={AUTOMATION_ENABLED:'true',GITHUB_REPOSITORY:'shoichi-shikita/ice-forest',GITHUB_TOKEN:'fake',JULES_API_KEY:'fake'};
function fixture(options={}) {
  const calls=[];
  const request=async (url,init)=>{
    calls.push({url,...init}); let data;
    if(url.endsWith('/repos/shoichi-shikita/ice-forest')) data={private:!!options.private,visibility:options.private?'private':'public',default_branch:'main'};
    else if(url.includes('/sessions?')) data={sessions:[{name:'sessions/123',outputs:[{pullRequest:{url:pr.html_url}}]}]};
    else if(url.endsWith('/sessions/123')) data={state:'COMPLETED',sourceContext:{source:'sources/github/owner/repo',githubRepoContext:{startingBranch:'main'}},outputs:[{pullRequest:{url:pr.html_url}}]};
    else if(url.endsWith('/sources/github/owner/repo')) data={githubRepo:{owner:options.wrongSource?'other':'shoichi-shikita',repo:'ice-forest'}};
    else if(url.includes('/pulls?')) data=[pr];
    else if(url.endsWith('/pulls/3')) data=options.noLabel?{...pr,labels:[]}:pr;
    else if(url.includes('/issues/3/comments?')) data=[summary()];
    else if(url.includes('/check-runs?')) data={check_runs:green,total_count:1};
    else if(url.includes('/pulls/3/reviews?')) data=[{id:1,user:{login:'chatgpt-codex-connector[bot]'},commit_id:'abc'}];
    else if(url.includes('/pulls/3/comments?')) data=[{user:{login:'chatgpt-codex-connector[bot]'},pull_request_review_id:1,path:'docs/guide.md',line:1,body:'Clarify the required label.'}];
    else if(url.endsWith('/issues/3/comments')) data={id:42};
    else if(url.endsWith(':sendMessage')) { if(options.timeout) throw Error('timeout'); data={}; }
    else throw Error('Unexpected request '+url);
    return {ok:true,status:200,json:async()=>data};
  };return {calls,request};
}
test('disabled configuration makes no external calls',async()=>{const m=fixture();await assert.rejects(run({...env,AUTOMATION_ENABLED:''},m.request));assert.equal(m.calls.length,0);});
test('private, no opt-in and mismatched Jules source cannot send messages',async()=>{
  for(const options of [{private:true},{noLabel:true},{wrongSource:true}]){const m=fixture(options);try{await run(env,m.request);}catch{}assert.equal(m.calls.filter(c=>c.method==='POST').length,0);}
});
test('intent is persisted before exactly one bounded feedback message',async()=>{
  const m=fixture();assert.equal((await run(env,m.request)).actions,1);const posts=m.calls.filter(c=>c.method==='POST');assert.equal(posts.length,2);assert.match(posts[0].url,/comments$/);assert.match(posts[1].url,/:sendMessage$/);assert.match(JSON.parse(posts[1].body).prompt,/untrusted review data/);assert.ok(m.calls.every(c=>c.redirect==='error'));
});
test('ambiguous message timeout never retries',async()=>{const m=fixture({timeout:true});await assert.rejects(run(env,m.request),/timeout/);assert.equal(m.calls.filter(c=>c.url.endsWith(':sendMessage')).length,1);});