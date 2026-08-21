---
mode: ask
model: Claude Sonnet 5
description: Review a finished slice against plan.md.
---
Review this slice against plan.md.

Review the diff or the files I attached. If you need context, look up the
specific file or symbol involved, but do not read the whole repo.

Check:
1. Correctness and regressions
2. Security and data handling
3. Edge cases and integration gaps
4. Whether the validation really proves the task is done

Do not suggest style-only changes.
List each issue on one line, marked high, medium, or low.
If you find nothing, say so and stop.
