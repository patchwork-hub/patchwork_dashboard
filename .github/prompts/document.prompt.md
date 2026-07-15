---
mode: agent
model: Kimi K2.7 Code
description: Generate or refresh docs for ONE unit (file, module, or public API).
---
Document this: ${input:target:Which file, module, or API? One unit only.}

Scope:
- One unit only. Do not walk the whole repo.
- Read the public interface (names, signatures, arguments, return values).
  Read function bodies only when the behavior is not clear from the interface.

Write or update:
- In-repo docs (/docs or README): update the section for this unit directly.
  If none exists, create a short one that matches the existing docs style.
- Separate docs repo/wiki: write the change as a short note at the end so it
  can be copied over.

Rules:
- Describe what the code does now. Do not invent features it does not have.
- Only change docs for this unit. Do not rewrite unrelated docs.
- Match the length and style of the existing docs. Do not pad.

Use a cheap model for this (Haiku or MAI Code 1 Flash) unless the unit needs
real architectural explanation.
