# Ice Forest development guidance

The project is a first-person psychological horror game titled アイスの森. Read DESIGN_RULES.md before any game work: it records the user's authoritative v0.31 handoff. The Windows executable distribution target is confirmed. Preserve the abandoned Japanese cedar plantation, physical ice-cream sticks, no progress counters or protagonist monologue, flashlight-off blackness, and deepest-area-then-return clear condition without requiring all sticks. PR #3's snow/crystal prototype is superseded. The actual v0.31 source is not yet available here; do not claim its implementation or verification has been inspected. Do not reconstruct or overwrite it from the earlier incorrect prototype.

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
