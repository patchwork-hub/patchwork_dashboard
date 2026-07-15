---
mode: agent
model: Claude Sonnet 5
description: Build one slice from plan.md, scoped and validated.
---
Implement this slice from plan.md.

Slice: ${input:slice:Which task from plan.md?}

Start with the files I attached. If you need more, search a specific area
(a named folder or symbol), not the whole repo. Read only the parts you need,
and do not load whole files unless required. List the files you used at the end.

Rules:
- Stop and report blockers. Do not guess.
- Do not widen scope. If the plan is wrong, say so and stop.
- If a command prints long output, summarise it. Do not paste it back.
- Never put secrets or real customer data in code or output.

When the slice is done:
1. Update the docs this slice affects so they match the new behavior.
   - Update in-repo docs (/docs, README) directly.
   - For the separate docs repo/wiki, write the change as a short note at the
     end of your summary so it can be copied over.
   - Only touch docs for what this slice changed. Do not rewrite whole docs.
2. Update progress.md
3. Run lint, format, build
4. Commit the code and the in-repo doc changes together in one commit.
5. Summarise the changes in under 100 words, then list any docs-repo/wiki
   updates still to copy over. Do not explain the code.
