# Branching and release policy

How code branches, versions, and ships. This sits **above** WORKFLOW.md: WORKFLOW.md is how you build one ticket; this is how tickets become branches, versions, and releases. Daily ticket work (feature branch, PR, review) is unchanged either way.

---

## First: is this repo a service or a released project?

Every repo is one of two kinds. It decides the whole model.

- **Service repo** — software we run and operate ourselves (internal tools, apps we host for a client). No outside user installs a version.
- **Released repo** — software external / open-source users install and run their own copy of. They run *versions*, report bugs against versions, and upgrade between them.

Mark each repo clearly (in its README). Some repos are both released **and** track an upstream project (a fork) — those follow the released model plus the upstream rules at the bottom.

---

## Service repos: trunk-based, promote to production

- `main` is the trunk and is always deployable.
- One short-lived branch per ticket, off `main`: `feature/TICKET-123-x` or `fix/TICKET-140-y`.
- PR into `main` (review + checks), squash-merge.
- Merge to `main` auto-deploys to **staging**.
- Test in staging, then **promote the same commit to production** (a tag/release or an approval in the deploy tool) — not a re-merge into a `production` branch.
- Fast-path production fix: `fix/` branch off `main` -> PR -> merge -> staging -> promote. Same as any ticket, minus the plan.

Keep `main` always-deployable. No long-lived `staging` or `production` branches — those are environments, reached by promotion.

---

## Released repos: main + stable branches + tags

External users run versions, so we add version machinery on top of the daily flow.

**Versioning: SemVer.**
- MAJOR (1.x -> 2.x): breaking changes.
- MINOR (1.1 -> 1.2): backward-compatible features.
- PATCH (1.2.1 -> 1.2.2): backward-compatible bug/security fixes.

**Branches and tags.**
- `main` is the integration trunk. Daily work merges here exactly as in service repos (feature branch -> PR -> main).
- At a release, cut a **stable branch** from `main`: `stable-1.2` (one per MINOR line).
- Tag releases on the stable branch: `v1.2.0`, then `v1.2.1`, `v1.2.2` for patches.
- Users install a **tag**, never `main`. `main` is bleeding edge and is not "production" for a released repo.

**Backporting (the key added step).**
- Fixes land on `main` first (so they are tested on the trunk).
- If a fix is needed by users on a released version, **cherry-pick it to the stable branch** and cut a patch release.
- New features are NOT backported — stable branches get bug and security fixes only.
- A backport is its own PR into the stable branch, referencing the original `main` PR (use `git cherry-pick -x` for traceability).

**Changelog.** PR titles feed release notes, so write them for the user/admin audience: start with Add / Change / Deprecate / Remove / Fix, present tense. Keep a CHANGELOG.

---

## Fast-path production fix in a released repo

For a released repo, an urgent fix may need to reach BOTH our own deployment and external users:
1. Fix on a `fix/` branch off `main`, add the regression test, PR, merge to `main`.
2. If users on a released version need it too: cherry-pick to the current stable branch and cut a patch tag (`v1.2.2`).
3. Paste the FIX comment on the origin ticket as usual, and note which versions got the fix.

For a service-only repo, ignore step 2 — there are no external versions to patch.

---

## Version support window (decide this before releasing)

Every stable branch you keep alive is ongoing backport work. Keep the list short.

- **Default: support the latest stable line only**, plus at most one previous line during a transition.
- Do NOT support every past version. "We support everything" is how backporting becomes unmanageable.
- When a line is dropped, say so in the changelog so users know to upgrade.

---

## Upstream-tracking repos (forks)

For a repo that is a fork of an upstream project:
- Track the upstream by its **stable release tags**, not its `main` (an upstream `main` is usually bleeding edge and not meant for production).
- Keep a long-lived `upstream-sync` branch that follows the stable line you target.
- Rebase the fork's own changes on top at each version bump. Keep the fork **thin** — the less you diverge from upstream, the smaller and cheaper each rebase.
- The fork's own day-to-day changes still use short-lived feature branches merged into the fork's `main`. Only the *upstream relationship* uses the long-lived branch.

---

## What does not change

The prompt workflow, PRs, reviews, sessions, and plan-in-backlog all operate at the feature-branch level, below this policy. Building a ticket is the same whether the repo is service or released. This policy only adds what happens **after** merge to `main`: promotion (service) or versioned stable-branch releases and backports (released).
