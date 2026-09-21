---
name: quality-gate
description: Pre-ship review gate for a codebase — run it before committing, merging, opening a PR, or releasing. Runs the repo's own lint/typecheck/test/build scripts and reports their real output, audits the diff against the project's written standards, checks the diff against the spec or ticket it came from (missing / scope creep / implemented-but-wrong), applies only mechanically-safe fixes, and returns Blocking / Major / Minor findings plus a separate no-severity Needs-validation list, ending in an Approve / Approve with Comments / Request Changes / Reject verdict. Use when someone says a module, endpoint, service, component, migration, or page is done and asks "is this ready to merge / production-ready", "review this", "does it follow our standards", "does this match the spec", or wants a security review of auth, validation, or data-access code — even without the words "skill" or "standards". Do NOT use it to write features, explain how code works, or scaffold specs.
---

# Quality Gate

A review that a strict human reviewer would sign, produced the same way every time.

The bar is **"would a careful reviewer approve this for production?"**, not "does it
run". When in doubt the verdict is **Request Changes** — a flagged non-issue costs a
second look; a missed Blocking costs an incident.

## What this is not

- **Not a linter.** Linters are step 3 of 6, and they are the cheap part.
- **Not an author.** It reviews and applies mechanically-safe fixes. It does not
  design features, rename things, or refactor.
- **Not a substitute for a security audit.** See `references/evidence-contract.md`
  for where that line sits and what to do at it.

---

## Step 1 — Resolve the standards

Standards are the source of truth and they belong to the project, not to this skill.
Read the project's own docs when they exist; fall back to the bundled checklists when
they do not.

1. Look for project standards. Try, in order, and stop at the first that exists:
   `docs/standards/`, `docs/requirements/standards/`, `standards/`, `.standards/`,
   `CONTRIBUTING.md`. Search upward from the working directory — in a multi-repo
   workspace the standards often live one level above the repo. Use glob/ls; do not
   assume a path.
2. If found, skim the documents relevant to the files in the diff. **They override
   anything bundled here when they conflict.**
3. If not found, use `references/` below. They are a faithful, general version of the
   same rules and are enough to run a full review.

| bundled file | read it when the diff includes… |
|---|---|
| `references/backend-checklist.md` | server code: controllers, services, repositories, DTOs, entities, migrations, workers, queues |
| `references/frontend-checklist.md` | UI: components, pages, loaders, forms, client-side state, rendering of user input |
| `references/security-checklist.md` | auth, authorization, input handling, uploads, logging, secrets, outbound URLs — **almost always** |
| `references/evidence-contract.md` | **every run that is about to write a security finding.** What it takes for a claim to count |
| `references/gates-and-fixes.md` | **every run** — how to find and run the repo's real gates, and the exact safe-fix policy |
| `references/go-live-checklist.md` | only when asked for a release / production-readiness review, not a per-change one |

> **Project config.** If the project has a `QUALITY-GATE.md` (see `templates/`), read
> it first: it names the lanes, the protected branches, the queue file, and any
> project-specific traps. It is optional; the skill works without one.

---

## Step 2 — Determine scope

- If the user named a file, folder, or module, review that.
- Else, in a git repo, review the **diff**: uncommitted changes, plus the branch
  against its base (`main`/`master`/`develop`, whichever exists).
- If the tree is clean and there is no branch delta, review the last commit.
- If there is no git and no path, ask which file or folder to review.

Review what changed **plus what it affects** — a changed DTO touches its controller,
its service, and any published API contract. Skip generated and vendored files.

**State the scope in one line at the top of the report**, so the reader knows exactly
what was and was not covered.

### Pin what the change was SUPPOSED to be

Everything else asks *is this code good?* This asks *is it the thing that was asked
for?* — and good code can fail it. Find the originating spec, in this order:

1. A path or spec the user named.
2. The project's spec directory, if it has one (`docs/specs/`, `docs/superpowers/specs/`, `spec/`).
3. An issue referenced in the commit messages (`#123`, `Closes #45`).
4. The open PR body.
5. The project's backlog or queue file, if it has one — an item there is a spec of sorts.

If none exists, write **"no spec available"** in the report and skip the Spec axis.
Do not invent one from the diff and then check the diff against it: that always
passes and proves nothing.

> This axis exists because the author and the reviewer are usually the same context,
> and a spec written an hour earlier stops being read. The characteristic failure is
> code that looks entirely correct on its own and is only wrong **next to the spec**.

---

## Step 3 — Run the repo's real gates

Machines catch mechanical problems faster than reading does. Run them first so your
reading time goes to judgment.

1. **Read the manifest and run the scripts that exist** — `package.json`,
   `Makefile`, `pyproject.toml`, `Cargo.toml`, whatever the project uses. Typically
   some of: lint, typecheck, test, build.
2. **Capture the actual output.** Report real pass/fail counts and the first real
   errors. Never a guess.
3. If a script does not exist, say so (`no "lint" script found`) and move on. Absence
   is not failure, and it is not a pass either.

Three traps that have each produced a false green, all covered in
`references/gates-and-fixes.md`:

- **Never pipe a gate and read `$?`** — `cmd | tail` returns `tail`'s status, not the
  gate's. Redirect to a file and read the tool's own exit code.
- **Run the gates that exist, not the ones you remember.** List the manifest's scripts
  and run each that is a gate. A suite you never ran is not a suite that passed.
- **An npm script is not always what CI runs.** If CI invokes a binary with flags the
  script omits, the script can exit 0 while CI fails. Compare them.

Record each result for the Gates table.

---

## Step 4 — Audit against the standards

Read each file in scope, route it to the matching checklist, and evaluate along these
dimensions:

- **Correctness** — requirements met, edge cases, null/undefined, failure paths.
- **Security** — see the evidence contract below before writing anything here.
- **Architecture** — layer boundaries respected; thin controllers; logic in services;
  persistence-only repositories; external calls where the project puts them.
- **API contract** — naming, versioning, consistent envelope, pagination on
  collections, documented; no breaking change without a version.
- **Data** — keys, audit fields, soft delete, naming, foreign keys and indexes,
  reversible migrations, no auto-sync in production.
- **Maintainability** — clear names, small functions, shallow nesting, no magic
  values, no dead or clever code, strict types, no escape hatches.
- **Testing** — changed logic comes with tests; critical flows covered; no
  sleep-based or order-dependent tests.
- **Performance, caching and limits** — ask the four **together** for every endpoint
  the diff touches, not only the one the ticket named: **bounded** · **cached where
  the project's policy says so** · **authorized on every door that reaches the same
  write** · **rate limited where it is public**. "It was already unbounded" is not a
  defence once the diff touches that line.
- **Spec fidelity** — only when Step 2 found a spec. Quote the spec line for each
  finding: **Missing** (asked for, absent or half-done) · **Scope creep** (behaviour
  nobody asked for — extra surface others may build on) · **Implemented but wrong**
  (present, not what the spec described — the one that hides, because the code reads
  fine on its own). A deviation is not automatically Blocking: judge it on
  consequence, and if the **spec** turned out wrong, say that instead.

### Before you write a security finding

**Read `references/evidence-contract.md`.** It is short, and it decides whether what
you are about to write is a finding at all. Three rules:

1. **Name a boundary AND a result.** Six rows: lower-trust principal · accepted input
   or action · intended control · crossed boundary · affected principal or resource ·
   observed or owner-observable result. A missing best practice with no principal and
   no crossed boundary is a hardening note, not a security finding.
2. **`needs-validation` is a state, and it carries no severity.** When the decisive
   fact is outside the repository — a proxy header, an IAM policy, a provider default,
   live configuration — say so with the exact missing fact and a safe way to check it.
   Do not guess presence *or* absence.
3. **Severity cannot exceed demonstrated impact.** Use the anchors in the contract.
   If you cannot state the concrete damage, it is lower than it feels.

### Classify every finding

- **🔴 Blocking** — must fix before merge. Confirmed security gap, missing
  authorization, data-corruption risk, undocumented breaking change, critical bug,
  architecture violation.
- **🟠 Major** — should fix before release. Missing tests for changed logic, missing
  validation, N+1 or unbounded query, incomplete error handling.
- **🟡 Minor** — optional. Naming, readability, small refactors.
- **🔍 Needs validation** — no severity. A source-grounded question blocked on a fact
  outside the repo.

If unsure between Blocking and Major, say so in the finding and lean stricter.

---

## Step 5 — Apply safe fixes only

A fix is safe only if a formatter or linter would make it and it **cannot change
runtime behaviour or a public contract**.

**Apply, then list:** formatter output; linter autofix for import order, unused
imports, const-over-let, quote and semicolon style, trailing commas.

**Report, never apply:** anything touching logic or control flow; replacing loose
types with real ones; adding or changing validation; renaming public symbols,
endpoints, fields or enum values; security fixes; architecture moves; schema and
migration changes.

Re-run the affected gate after fixing so the report reflects the fixed state. Full
policy: `references/gates-and-fixes.md`.

---

## Step 6 — Emit the verdict

Always produce exactly this structure:

```
# Quality Gate — <scope, e.g. "feature/x vs develop · 6 files">

## Summary
<1–3 sentences: what was reviewed and overall health>

## Gates
| Gate      | Result                                            |
|-----------|---------------------------------------------------|
| Lint      | ✅ pass (3 auto-fixed) / ❌ 5 errors / ⏭ no script  |
| Typecheck | ✅ pass / ❌ 2 errors                              |
| Tests     | ✅ 42/42 / ❌ 2 failed / ⏭ none                    |
| Build     | ✅ pass / ❌ fail / ⏭ skipped                      |

## Spec fidelity — <spec path or issue, or "no spec available">
- **Missing** — <what the spec asked for and the diff does not do>, spec: "<quoted line>"
- **Scope creep** — <behaviour nobody asked for>
- **Implemented but wrong** — <present but not as described>, spec: "<quoted line>"
<or> Matches the spec. <or> No spec available — axis skipped.

## 🔴 Blocking  (must fix before merge)
- `path/file.ts:24` — <defect> — violates <standard>. <smallest effective fix>.
<or> None.

## 🟠 Major  (should fix before release)
<or> None.

## 🟡 Minor  (optional)
<or> None.

## 🔍 Needs validation  (no severity — the decisive fact is outside the repo)
- `path/file.ts:NN` — <source-grounded hypothesis>, blocked on <exact missing fact>.
  Check by: <safe owner-observable or local step>.
<or> None.

## Auto-fixes applied
<or> None.

## Verdict
**Request Changes** — <short justification tied to the findings above>
```

The verdict is one of **Approve**, **Approve with Comments**, **Request Changes**,
**Reject**.

Do **not** Approve if any of these hold:

- A Blocking issue exists.
- A **confirmed** security concern exists. A `Needs validation` entry does not block
  on its own — it is a question, not a defect. Say plainly in the verdict that it is
  open, and never promote it to Blocking "to be safe": doing that is what makes a
  security list unreadable, because nobody can then tell measured from suspected.
- A breaking API or schema change is present without versioning and documentation.
- A critical test is failing.
- An architecture standard is violated.
- The diff departs from its spec and the departure is neither called out nor agreed.
  A silent departure is not a style question: whoever reads the spec next will believe
  something that is not true of the code.

Reserve **Reject** for a fundamentally wrong approach.

---

## Notes

- Be specific and kind. Findings are about the code's production-readiness, not the
  author.
- Do not pad. "None." in a tier is a good outcome — say it plainly.
- **Never claim a gate passed without running it, and never invent a finding to look
  thorough.** Every finding cites a file:line and the standard it violates.
- **Review is a separate pass from writing.** If you wrote the code, you are not the
  one to approve it — and that includes the fix for a review finding.
