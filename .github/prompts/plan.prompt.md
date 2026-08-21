---
mode: ask
model: Claude Sonnet 5
description: Return a scoped, commit-sized task plan in chat.
---
Create a self-contained Markdown plan for: ${input:goal:What is the goal?}

Do not edit files. Return the full plan in chat so it can be saved locally.

Start with the files I attached. If you need more, search a specific area
(a named folder or symbol), not the whole repo. Read only what you need.
List the files you used.

Sections:
- Objective
- Assumptions
- Scope and non-goals
- Docs impact (see below)
- Tasks in order
- Validation for each task
- Risks and rollback

Docs impact:
- List which docs this change affects: in-repo docs (/docs, README) and the
  separate docs repo/wiki.
- For each, say whether it is already out of date with the current code.

Then, in "Tasks in order", every task that changes behavior must include its
own doc-update step. Write it into the task itself, for example:
  Task 2: Add rate-limit setting
    - code: add the setting and read it in the middleware
    - docs: update /docs/config.md with the new setting; note the same change
      for the docs wiki
    - validation: [command]
Do not add a single "update docs" task at the end. Each task carries the docs
it affects, so /execute updates docs in the same commit as its code.

Rules:
- Each task changes at most 3 files
- Each task is one commit
- Prefer existing patterns
- Do not expand scope

Keep plan.md under 500 words. Do not write code.

Model: default is Sonnet 5. Escalate to a frontier model (Opus 4.8, or GPT 5.6
Sol on approved teams for a different-family view) ONLY if any of these is true:
- the plan spans more than one repo or service
- it changes architecture or a data model
- you cannot describe the approach in one sentence
If none are true, Sonnet 5 plans it.
