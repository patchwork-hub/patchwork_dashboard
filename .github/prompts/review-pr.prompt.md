---
mode: ask
model: GPT-5.3-Codex
description: Review a pull request before merge and give a clear merge decision.
---
Review this change before merge.

Review only the diff or the files I attached. If you need context, look up the
specific file or symbol involved, but do not read the whole repo.

Check, in this order:
1. Correctness: does it do what the PR says, without breaking existing behavior?
2. Edge cases and error handling that are missing.
3. Integration: anything it touches that could break elsewhere.
4. Whether the tests and validation actually prove the change works.

Do not comment on style or formatting. That is the linter's job.

Output:
- List each issue on one line, marked high, medium, or low.
- End with one line: MERGE, MERGE AFTER FIXES, or DO NOT MERGE, and why.
- If you find nothing, say "No blocking issues" and stop.
