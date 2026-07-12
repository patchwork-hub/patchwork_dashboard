# Copilot instructions

These rules apply to every Copilot request in this repo. Keep this file short — it is added to every message, so extra words cost tokens each time. The code-review rules are placed first because the automatic reviewer only reads the start of this file.

## For code review

When reviewing a pull request:
- Focus on, in order: correctness and regressions; security; whether the tests actually prove the change works; missing edge cases and error handling.
- Security specifically: injection from unvalidated input, missing auth or authorization checks, secrets or credentials in code/logs/output, unsafe handling of user input or file paths, and PII or token exposure.
- Tests: check that they prove the intended behavior, not just that they pass. Flag tests that assert wrong or buggy behavior.
- Do NOT comment on style or formatting — the linter handles that.
- Mark each issue critical, high, medium, or low. Be specific: name the file and the risk in a few words.
- If there are no blocking issues, say so briefly.

## Always
- Start with the files the developer attached. If you need more, search a specific folder or symbol and read only what you need. Never scan the whole repo.
- Prefer existing patterns and libraries already in this repo.
- Stop and report blockers instead of guessing.
- If a command prints long output, summarise it. Do not paste the full output back.
- Prefer smart codebase search (#codebase) over reading whole files, when available.

## Never
- Never put secrets, credentials, or real customer data in code or output.
- Do not widen the scope of a task without being asked.
- Do not make style-only changes unless asked.

## Output
- Be concise. Do not explain code unless asked.
- When you finish a task, give a short summary, not a walkthrough.

<!--
Standing rules and review rules live HERE (always-on; the reviewer reads the top).
Task-specific structure lives in .github/prompts/*.prompt.md (loaded only when invoked).
The automatic code reviewer reads only the first ~4000 characters of this file,
so keep the review section near the top and keep the whole file lean.
-->
