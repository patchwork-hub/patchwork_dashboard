---
mode: ask
model: Claude Sonnet 5
description: Shape an idea and compare approaches before writing any code.
---
Goal: ${input:goal:What do you want to solve?}

Use the files I attached. If something is unclear, you may look up one
specific file or symbol, but do not scan the whole repo.

Before any code:
1. Give 2-3 approaches with trade-offs.
2. Recommend the simplest one that fits this repo.
3. Ask a question only if the answer would change the approach.

Do NOT:
- write code
- scan the whole repo

Answer in under 200 words.
