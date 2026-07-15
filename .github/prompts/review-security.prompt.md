---
mode: ask
model: Claude Opus 4.8
description: Focused security review of a change.
---
Do a security review of this change.

Review only the diff or the files I attached. Look up a specific file or symbol
if you need context, but do not read the whole repo.

Look specifically for:
1. Injection risks (SQL, command, template, etc.) from unvalidated input.
2. Authentication and authorization gaps: missing checks, privilege escalation.
3. Secrets or credentials in code, logs, or output.
4. Unsafe handling of user input, file paths, or external data.
5. Sensitive data exposure (PII, tokens) in responses, logs, or errors.

Ignore style, performance, and general code quality. Security only.

Output:
- List each finding on one line, marked critical, high, medium, or low.
- For each, name the file and the specific risk in a few words.
- If you find nothing, say "No security issues found" and stop.
