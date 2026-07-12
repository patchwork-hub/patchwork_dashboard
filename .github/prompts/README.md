# Team prompts

Reusable prompts for GitHub Copilot. You do not paste these — you invoke them in Copilot Chat and just give your goal.

## How to use

New here? Read **WORKFLOW.md** — it shows which command to use at each step of a task, start to finish. For how code branches, versions, and releases, see **BRANCHING.md**.


In Copilot Chat, type the slash command and add your goal:

- `/brainstorm` — shape an idea before any code
- `/plan` — return a task plan in chat (save locally with `pbpaste > plan.md`)
- `/execute` — build one slice from `plan.md`
- `/review` — quick review of a finished slice
- `/review-pr` — review a pull request before merge, with a merge decision
- `/review-security` — focused security review (injection, auth, secrets)
- `/review-tests` — check whether the tests really prove the change is correct
- `/document` — generate or refresh docs for one file, module, or API

Attach the files you want the model to use (with `#file` or the `+` button) **before** running the command. The model uses those first. If it needs more and you have not attached it, the prompts let it search a specific folder or symbol — see "About search" below.

## Which model each prompt uses (default, and when to move up)

Each prompt sets a default model that fits its phase. The default handles the normal case; move up only when the situation is genuinely harder. Picks are on price and fit, not brand.

| Prompt | Default | Move up to | When to move up |
|--------|---------|-----------|-----------------|
| `/brainstorm` | Sonnet 5 | Opus 4.8 | The problem is architectural or has no obvious shape. |
| `/plan` | Sonnet 5 | Opus 4.8 (or Sol, approved teams) | Spans >1 repo/service, changes architecture or a data model, or you can't describe the approach in one sentence. |
| `/execute` | Sonnet 5 | GPT 5.3-Codex | Long, code-heavy run across many files (switch once, not back and forth). |
| `/document` | Kimi K2.7 Code | Sonnet 5 | Architecture docs that need real synthesis, not just restating code. |
| `/review-pr` | GPT 5.3-Codex | Opus 4.8 | High-risk or high-blast-radius merge. |
| `/review-security` | Opus 4.8 | + a 2nd family (Codex) | Always on for auth/input/data changes; add a cross-check for critical paths. |
| `/review-tests` | GPT 5.3-Codex | Sonnet 5 | Complex behavior where test-vs-intent is subtle. |

Two rules that sit on top of the table:
- **Cheaper-first within a phase.** A trivial plan, a one-file review, or a boilerplate slice can drop a tier below the default.
- **Switch models as few times as possible.** The build session (brainstorm, plan, execute) stays on one model for a warm cache; reviews run in a separate session where switching is cheap. Only move up at a natural boundary, not mid-phase. See WORKFLOW.md.

Note: defaults for `/document`, `/execute`, and the code reviews rest on price and GitHub's task classification, not independent coding benchmarks. Treat them as starting defaults to confirm on real work.

## Docs stay current as you work

Docs are handled inside the normal flow, not as a separate chore:

- **`/plan`** records which docs a change affects and writes a doc-update step **into each task** in the plan. So the plan already contains the doc work in order — there is nothing separate to remember.
- **`/execute`** carries out each task from the plan, including its doc step, and commits the in-repo docs **in the same commit as the code**. Changes for the separate docs repo/wiki are listed at the end of the summary to copy over.
- **`/document`** is optional, for deliberate doc work outside a task — writing docs for existing code that has none, or a one-off refresh. Normal feature work does not need it, because `/plan` already puts the doc steps in the plan. It scopes to one unit, reads interfaces before bodies, and suggests a cheap model.

Never run docs generation as a repo-wide agent loop. One unit at a time.

## Why these prompts look strict

Prompt words cost almost nothing. What costs money is what the model **reads** and what it **writes**. So every prompt:
- uses attached files first, and searches narrowly (a named folder or symbol) only when it needs more,
- limits the length of the answer (output costs about 5x input per token),
- tells the model to summarise long command output instead of pasting it back.

**About search:** you do not have to attach every file. If you cannot, the prompts let the model search — but only a specific area, reading only what it needs, and listing what it used. What costs money is an unbounded crawl of the whole repo that drags large amounts of code into context and re-bills it every turn. Narrow search avoids that. Where available, `#codebase` does a smart search that pulls relevant snippets instead of whole files, which is cheaper.

Standing rules that never change (code style, patterns, never paste secrets) live in `.github/copilot-instructions.md`, not in these prompts, so they are not re-sent inside every prompt.

## How we know if a prompt is working

Three signals: did it work the first time (fewest retries), what did it cost, did the output survive review.

- **Record:** these prompts are version-controlled, so every change is a dated commit — that is our change history.
- **Log failures only:** when a prompt fails or needs 3+ tries, add one line to `PROMPT_LOG.md`. We do not log successes.
- **Review monthly:** ~20 minutes reading the log against the Copilot usage trend. If a prompt shows up often, we change it here via PR.
- **For heavy prompts (mainly `/execute`):** keep 3–5 real sample tasks. When we change the prompt, run old vs new on the same tasks and compare cost and whether it worked.

Keep this lightweight. Measuring the prompts should never cost more attention than the prompts save.
