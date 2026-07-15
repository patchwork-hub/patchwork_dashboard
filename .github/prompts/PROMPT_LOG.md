# Prompt log

Log a line here **only when a prompt fails or needs 3+ tries.** We do not log successes — failures are rarer and tell us far more.

**When to add a row**
- A prompt gave a wrong or unusable result.
- You had to re-prompt three or more times to get it right.
- The model searched the whole repo, wrote far too much, or ignored the scope.

**How we use this:** reviewed once a month (about 20 minutes) alongside the Copilot usage trend. If a prompt shows up often, we change it. Prompt changes are made in the `.prompt.md` files and go through a normal PR.

---

## Failures

| Date | Prompt | Model | What went wrong | Fix / follow-up |
|------|--------|-------|-----------------|-----------------|
| 2026-07-10 | /execute | Sonnet 5 | Searched the whole repo instead of the listed files | Example row — delete once real entries exist |
|  |  |  |  |  |

---

## Monthly review notes

Short notes from each monthly review: what changed, and whether the cost trend moved.

- **2026-07 —** _(first review pending)_
