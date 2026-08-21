# Task flow: which prompt, when

The prompts are meant to run in order, from starting a task to finishing it. You do not have to use every one — small tasks skip most of them. Below is the full flow, then the short version.

Before you start any prompt: attach the files you want the model to use (with `#file` or the `+` button). The prompts use those first and only search further if needed.

**IDE mode matters too.** VS Code has a mode toggle (Plan / Agent) next to the chat box, separate from these prompts. Pick the mode that matches the step:

| Step | IDE mode | Prompt |
|------|----------|--------|
| Brainstorm | Plan | `/brainstorm` |
| Plan a task | Plan | `/plan` |
| Build a slice | Agent | `/execute` |
| Document | Agent | `/document` |
| Review | Plan (Ask) | `/review-pr`, `/review-security`, `/review-tests` |

Rule of thumb: **Plan mode** for thinking and reviewing (the model should not edit files), **Agent mode** for building (the model should edit and run commands). "Plan mode" (the IDE toggle) and `/plan` (this prompt) are two different things with the same name: the mode keeps the model from editing, the prompt gives the plan our house structure. Use them together for the planning step.

`/plan` is read-only by design: it returns the plan in chat. To hand off into execution, copy the full response and run `pbpaste > plan.md` from the repository root.

---

## The full flow

### 1. `/brainstorm` — only when the approach is unclear
Use this when you are not sure how to solve the problem yet.
- You give: the problem, and any files you already know are involved.
- You get: 2-3 approaches with trade-offs, and a recommendation.
- Skip it when: the approach is already obvious.

### 2. `/plan` — for anything bigger than a one-file change
Turns the goal into an ordered list of small, commit-sized tasks.
- You give: the goal.
- You get: a plan response with objective, scope, tasks in order, validation, risks, and — inside each task — the doc updates that task needs.
- Capture step: copy that response and run `pbpaste > plan.md` from the target repository root.
- Skip it when: the task is a single clear slice you could do in one commit.
- **Check the output:** read `plan.md` after capture. Are the tasks small? Does each task that changes behavior include its doc step? Fix the plan before moving on.

### 3. `/execute` — once per task in the plan
Builds one slice from `plan.md`. Run it again for the next slice, and so on.
- You give: which task from `plan.md`.
- It does: writes the code, updates the affected in-repo docs, updates `progress.md`, runs lint/format/build, and commits the code and docs together.
- After each run: it lists any separate docs-repo/wiki changes to copy over, and summarises what changed.
- Repeat until `progress.md` shows the plan is done.

### 4. Review — before you push or open a PR
Pick the review that fits. For a normal change, `/review-pr` is enough. Add the others when the change is risky.
- `/review-pr` — the everyday pre-merge check. Ends with MERGE, MERGE AFTER FIXES, or DO NOT MERGE.
- `/review-security` — run this too when the change touches auth, input handling, data, or anything sensitive.
- `/review-tests` — run this when you want to be sure the tests prove the behavior, not just pass.
- (The older `/review` is a lighter quick-look; prefer `/review-pr` for real PRs.)

### 5. `/document` — only for standalone doc work
You usually do **not** need this, because `/plan` and `/execute` already keep docs in step with the code.
- Use it when: documenting existing code that has no docs, or doing a one-off refresh.
- It scopes to one file or API and suggests a cheap model.

### 6. Finish it yourself
The model saying "done" is not done.
- Test the change by hand and confirm it does what you wanted.
- Copy over any docs-repo/wiki notes the execute step listed.
- Save the plan, then clean up (see below).
- Then close the task.

**Plan and progress files are scratch.** `plan.md` and `progress.md` are gitignored (see `.gitignore.copilot-snippet`) and never committed.

**Capture the plan at the review / PR handoff — while the file still exists.** When you finish building and open the PR:
- **Paste `plan.md` into the backlog ticket** (as a comment). Do this now, not at ticket close — the scratch file gets deleted, so grab it while it is still on disk. The ticket is the durable record of what was built and why; it lives with the requirement, the discussion, and the PR link.
- **Then delete both `plan.md` and `progress.md`.**

The ticket moves to "in production" later on its own timeline, with the plan already attached. There is nothing to archive in the repo, nothing to index, and nothing to maintain — the plan's lasting home is the backlog ticket.

---

## Short version

```
unclear how to solve it?   -> /brainstorm
bigger than one file?      -> /plan        (then check plan.md)
build each task            -> /execute     (repeat per task; docs + commit included)
before push / PR           -> /review-pr   (+ /review-security, /review-tests if risky)
docs for old code?         -> /document    (only if needed)
always at the end          -> test it yourself, copy any wiki notes, close
```

## When a bug is found in production

A bug found after a ticket shipped does NOT reopen the old ticket. The old ticket's scratch files are already gone, and its plan described the original work. Treat the bug as a new, small task.

**First: is it urgent?**
- **Outage, data at risk, or serious breakage** → this is incident response, not this workflow. Roll back or fix forward to restore service first, following the production-rollback approval process. Do the process below afterwards. Do not run the prompt flow while production is down.
- **Not urgent** (wrong behavior, edge case) → use the flow below.

**Fast-path for a small, obvious fix.** If the bug is quick to fix and you do not want to open a new ticket, use this lane. It skips the ticket and the plan, but NOT the test or the review.

Use the fast-path only if ALL four are true:
- small (a line or a few lines, a couple of files at most)
- obvious (you know *why* it fixes the bug, not just that it does)
- low-risk (not auth, payments, data integrity, or anything security-sensitive)
- you can write a test that proves the fix

If any one is false, use the full flow below instead.

Fast-path steps:
1. Fix it on a branch.
2. **Add a regression test** — a test that would have caught this bug. Not optional.
3. **Open a PR** — it still goes through normal review and checks. Fast-path skips the ticket, not the review.
4. **Paste a comment on the original ticket the bug came from**, using the FIX format (see "Comment formats" at the end of this doc).

   Several quick fixes on the same feature stack up as dated FIX comments on that
   ticket — a readable fix history in one place. "Test: none" is a red flag; if you
   cannot write the test, the fix was not obvious enough — use the full flow.

**For a non-urgent production bug:**
1. **Open a new ticket** for the bug and link it to the original ("found in production, from TICKET-123"). The original stays closed; its plan is already in its comments.
2. **Run the normal flow, scaled to the bug:**
   - Usually skip `/brainstorm` — you know what is broken.
   - Use `/plan` only if the fix spans multiple files or is not obvious. A small fix goes straight to `/execute`.
   - `/execute` the fix as one slice, with the doc update if behavior changed.
   - **Add a regression test.** The fix is not done until a test exists that would have caught this bug. Run `/review-tests` to confirm the test asserts the correct behavior, not the bug.
   - `/review-pr`, and `/review-security` too if the bug was in auth, input, or data handling.
3. **Stricter finish.** Because the bug escaped once, "test it yourself" means: reproduce the original failure, then confirm the fix resolves it in a production-like way. Not just that the code changed.
4. **One-line note in the bug ticket:** what let it reach production (missed case in the plan, no test for that path, review missed it). Not blame — a signal. If the same kind of miss shows up often, a gate has a blind spot to fix.

## Tiny tasks

A one-line fix or a rename does not need this flow. Just make the change, and run `/review-pr` if you want a second set of eyes. Do not open a plan for work that is faster to do than to describe.

## A real example, start to finish

One ticket: **"Add a per-server rate limit for API posts."** Here is the whole flow, with what you type and what you get.

**Ticket is a bit unclear, so start with brainstorm.** Attach the two files you think are involved, then:

> `/brainstorm`
> Goal: add a per-server rate limit for API post creation.

You get 2-3 approaches (e.g. middleware vs. a check in the request handler vs. a shared library), each with trade-offs, and a recommendation. Good enough to plan. *(Same chat continues.)*

**Now plan it.**

> `/plan`
> Goal: add per-server rate-limit middleware for API post creation.

You get `plan.md` with, for example:
- Task 1: add the `rate_limit_per_server` setting — code + docs update to `/docs/config.md`
- Task 2: add the middleware that reads it — code + validation `bundle exec rspec spec/middleware`
- Task 3: wire the middleware into the API stack — code + docs note for the wiki

You read it: tasks are small, each has its doc step. Good. *(Same chat.)*

**Build task 1.**

> `/execute`
> Slice: Task 1 — add the rate_limit_per_server setting

It adds the setting, updates `/docs/config.md`, updates `progress.md`, runs lint/build, and commits code + docs together. It ends: "Wiki note to copy: document new setting on the Config page."

**Build task 2, then task 3** the same way — `/execute` once per task, same chat. On a long ticket you would start a fresh chat every few tasks and re-point at `plan.md`.

**Reviews — new chat now.** Start a fresh chat (reviews don't need the build context):

> `/review-pr`

You get a line-by-line list and a verdict: MERGE AFTER FIXES (one medium: missing error when the limit is malformed).

Because this touches request handling, also:

> `/review-security`

It checks for bypasses and input handling and returns "No security issues found." *(Run this last — it uses a different model, so switching here is the cheap place to do it.)*

**At the PR handoff:** paste `plan.md` into the backlog ticket as a comment (see "Comment formats" below for the exact template), then delete `plan.md` and `progress.md`. The plan is now safe in the ticket.

**Finish it yourself.** Fix the medium from review, test the rate limit by hand (hit the endpoint over the limit, confirm it blocks), copy the wiki note onto the Config page, then close the ticket.

**A tiny version of the same idea:** if the ticket were just "rename `postsLimit` to `postCreationLimit`," you skip all of it — make the change, run `/review-pr` if you want a second look, done.

## Sessions and model switching

One chat session is one **task** (ticket). Not one session per prompt, and not one session for everything you do all day.

- **Build session:** run `/brainstorm`, `/plan`, and `/execute` in the **same** chat. They share context and one model (Sonnet 5 by default), so the cache stays warm and it costs less. Do not open a new chat between these phases.
- **Review session:** run the `/review-*` prompts in a **separate** chat. Reviews start from the diff, so they do not need the build session's context — this is the cheap, natural place to change models.
- **Between tickets:** start a fresh chat. The old task's context is dead weight for the next one.
- **Long tasks:** on a big multi-slice task, start a fresh chat every few slices. Re-attach the current files and point at `plan.md` and `progress.md` — they hold the state, so you resume without losing the thread.

**About switching models:** switching the model inside one chat clears the prompt cache and costs more. So switch as little as possible:
- Keep one model through the whole build session.
- Only change model at the build-to-review boundary, where the cache was not helping anyway.
- If you run several reviews, do the same-model ones first (`/review-pr`, `/review-tests` on Codex) and the different-model one last (`/review-security` on Opus) — that way you switch once, not back and forth.


### Switching model the cheap way (use plan.md and progress.md)

Because the state lives in `plan.md` and `progress.md`, you can throw away a chat and start a clean one with a different model, and lose nothing. Do it this way instead of switching model inside a chat:

1. **Finish the current slice first** (so `/execute` writes `progress.md`). Never start a fresh chat mid-slice.
2. **Open a new chat** and pick the model you want for the next phase.
3. **Paste the resume line:**

   > Read `plan.md` and `progress.md`. Continue from the next unfinished task. Use only the files I attach.

The new chat reads the two files in one cheap step and carries on. You get the right model per phase and never pay the mid-chat cache reset. Use the same move when a chat gets long or bloated: finish the slice, new chat, same model, resume line.

## If a prompt fails

If a prompt gives a bad result or needs 3+ tries, add one line to `PROMPT_LOG.md` (date, prompt, model, what went wrong). We review that log monthly to improve the prompts.

## Comment formats

Two fill-in formats for pasting into the backlog ticket. Keep the header lines — they are what make several comments on the same ticket readable as a history, instead of a wall of text.

### Plan paste (at the review / PR handoff)

```
PLAN — [ticket title] — YYYY-MM-DD
PR: [link]
Model used: [e.g. Sonnet 5 / Codex]

[paste the plan.md content here]

Shipped: [what actually landed, if it differed from the plan]
```

The `Shipped` line matters — plans change during execution, and the useful record later is what you *did*, not only what you intended.

Example:

```
PLAN — Add per-server rate limit for API posts — 2026-07-11
PR: github.com/org/repo/pull/275
Model used: Sonnet 5

Objective: rate-limit API post creation per server via middleware.
Tasks:
1. Add rate_limit_per_server setting
2. Add middleware that reads it
3. Wire middleware into the API stack
Validation: bundle exec rspec spec/middleware

Shipped: as planned, plus a malformed-limit guard added during review.
```

### Fast-path FIX comment (on the original ticket)

```
FIX — YYYY-MM-DD — [one line: what broke]
PR: [link]
Cause: [why it happened, one line]
Fix: [what you changed, one line]
Test: [the regression test added]
```

`Cause` and `Fix` are separate on purpose — the cause is what is actually useful later ("the setting wasn't validated" tells the next person something; "changed the middleware" doesn't). "Test: none" is a red flag — see the fast-path rules above.

Example:

```
FIX — 2026-07-11 — rate limit rejected valid requests at exactly the limit
PR: github.com/org/repo/pull/288
Cause: off-by-one — used > instead of >= on the counter
Fix: changed comparison in RateLimitMiddleware#exceeded?
Test: spec asserts the Nth request passes and N+1 blocks
```
