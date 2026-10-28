# Ice Forest development guidance

The project is a horror game titled アイスの森. The user has not yet supplied confirmed gameplay, story, engine, platform, or asset requirements. Do not invent or present them as approved requirements.

## Boundaries

- Additional charges beyond existing ChatGPT Plus and Google AI Pro subscriptions must remain zero.
- Do not enable paid APIs, purchase credits, change subscriptions, grant external access, or expose secrets.
- GitHub Actions must use standard runners only in public repositories. Preserve the job-level private-repository guard. Do not add caches, artifacts, paid hosting, or larger runners without an approved cost-safe design.
- Work through reviewable PRs. Never automatically merge, deploy, or delete user data.
- Stop on rate limits or ambiguous non-idempotent requests. Do not silently retry task creation or start unlimited correction loops.
- Preserve credential isolation: only trusted default-branch automation may receive secrets. Never run untrusted PR code with credentials.

## Validation

Run `node --test automation/*.test.mjs` for automation changes. These tests mock external calls and do not prove live account integration. Do not execute automation/e2e.mjs locally as a unit test: it intentionally creates one bounded Jules task using Actions credentials.

## Code Review Rules

### Cost and permissions
Flag changes that remove cost guards, introduce paid API fallbacks, consume paid review credits, broaden credential exposure, or bypass required authorization.

### Honest status and bounded execution
Flag claims of completed cloud verification without linked evidence, unbounded task retries, automatic merges, or unapproved game requirements presented as settled specifications.
