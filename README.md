# agent-quality-skills

[![npm](https://img.shields.io/npm/v/agent-quality-skills)](https://www.npmjs.com/package/agent-quality-skills)
[![licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

A pre-ship **quality gate** skill for coding agents (Claude Code, Cursor, Codex and
others). Ask *"is this ready to merge?"* and the agent:

1. runs your repo's real lint, typecheck, test and build scripts;
2. reviews the diff against your written standards **and** against the spec it came from;
3. applies only fixes a formatter could make;
4. returns a structured report: Blocking / Major / Minor findings and a verdict.

It installs alongside Cloudflare's **security-audit** skill. The two do different jobs:

| | reviews | cost | when |
|---|---|---|---|
| **quality-gate** (here) | a **diff** | one agent, minutes | every change, before merge |
| **security-audit** ([Cloudflare](https://github.com/cloudflare/security-audit-skill)) | a **system** | many agents, hours | scheduled, before a pen test |

The gate reviews and applies mechanically-safe fixes. The audit surveys and reports, and
does not modify source. Neither replaces the other.

---

## Install

Pick one. All of them install the same files.

**skills CLI** ([skills.sh](https://skills.sh)): detects your agents and asks where to
install.

```bash
npx skills add captainkie/agent-quality-skills        # the gate
npx skills add cloudflare/security-audit-skill        # the audit, from upstream
```

**npm package**: installs both skills into Claude Code in one command.

```bash
npx agent-quality-skills                 # both, into ~/.claude/skills
npx agent-quality-skills --gate-only     # just the gate, no network or git needed
npx agent-quality-skills --project       # into ./.claude/skills, for one repo
npx agent-quality-skills --dir <path>    # somewhere explicit
```

**Shell script**: for machines without Node. It takes the same flags.

```bash
curl -fsSL https://raw.githubusercontent.com/captainkie/agent-quality-skills/main/install.sh | bash
```

Re-running any of them updates in place. Nothing outside the chosen skills directory is
written, and no shell profile is touched.

Updating and removing:

```bash
npx skills update quality-gate     # if installed with the skills CLI
npx agent-quality-skills           # if installed with npm: just run it again
npx skills remove quality-gate
```

### Optional: per-project config

```bash
curl -fsSL https://raw.githubusercontent.com/captainkie/agent-quality-skills/main/templates/QUALITY-GATE.md -o QUALITY-GATE.md
```

Fill it in at your repo root. It tells the gate where your standards live and which
changes get the full review versus a batched one (lanes). It also lists your protected
branches and merge rules, and any project traps a reviewer cannot infer from the code.
The gate works without it.

---

## Using it

No special command. Ask in plain words once the work is done:

> is this ready to merge? · review this branch · does this follow our standards? ·
> does this match the spec in docs/specs/checkout.md? · security-review the auth changes

It triggers on those requests even without the words "skill" or "standards". It does
**not** trigger for writing features, explaining code, or scaffolding specs. It is a
reviewer, not an author.

---

## What it does, step by step

The gate runs the same six steps, in the same order, every time. That is the point:
two reviews of the same diff should not differ because one reviewer was tired.

### Step 1 — Resolve the standards

**Goal:** review against *your* rules, not the agent's taste.

- Looks for your written standards, stopping at the first that exists:
  `docs/standards/` → `docs/requirements/standards/` → `standards/` → `.standards/` →
  `CONTRIBUTING.md`. It searches **upward** from the working directory, because in a
  multi-repo workspace the standards often live one level above the repo.
- Reads `QUALITY-GATE.md` first if the project has one.
- **Your docs override the bundled checklists** wherever the two conflict.
- If you have no docs, it falls back to the bundled checklists. It reads only the ones
  that match the files in the diff:

| bundled reference | read when the diff includes… |
|---|---|
| `backend-checklist.md` | controllers, services, repositories, DTOs, entities, migrations, workers, queues |
| `frontend-checklist.md` | components, pages, loaders, forms, client state, rendering user input |
| `security-checklist.md` | auth, authorization, input handling, uploads, logging, secrets, outbound URLs. Almost always |
| `evidence-contract.md` | every run that is about to write a security finding |
| `gates-and-fixes.md` | every run: how to find and run the real gates, and the safe-fix policy |
| `go-live-checklist.md` | release / production-readiness reviews only |

### Step 2 — Determine scope, and pin what the change was supposed to be

**Goal:** say exactly what was reviewed, and what it was meant to do.

- **What to review:** the path you named. Otherwise the uncommitted changes plus the
  branch against its base (`main` / `master` / `develop`). On a clean tree it reviews
  the last commit. It also covers **what the change affects**: a changed DTO pulls in
  its controller, its service and the published API contract. Generated and vendored
  files are skipped.
- **One line at the top of the report** states the scope, so the reader knows what was
  *not* covered.
- **What it was supposed to be.** It looks for the originating spec in this order: a
  path you named → the project's spec directory → an issue referenced in the commits →
  the PR body → the backlog file. If there is none, the report says
  **"no spec available"**. The gate never invents a spec from the diff, because
  checking a diff against itself always passes.

### Step 3 — Run the repo's real gates

**Goal:** let machines catch the mechanical problems, so reading time goes to judgement.

- Reads the manifest (`package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, …) and
  runs **the scripts that exist**: lint, typecheck, test, build.
- Reports **real counts and the first real errors**, never a guess. A missing script is
  reported as `⏭ no script`, which counts as neither a pass nor a failure.
- It guards against three traps that have each produced a false green:
  - **Piping a gate hides its result.** `cmd | tail` returns `tail`'s exit code, not
    the gate's.
  - **A suite you remember is not the suite that exists.** It lists the scripts and
    runs every one that is a gate.
  - **The npm script may not be what CI runs.** When CI passes flags the script omits,
    the script can exit 0 while CI fails, so the two are compared.

### Step 4 — Audit against the standards

**Goal:** the judgement a careful reviewer brings, on nine axes.

| axis | asks |
|---|---|
| **Correctness** | requirements met · edge cases · null / undefined · failure paths |
| **Security** | held to the evidence contract (below) before anything is written |
| **Architecture** | layer boundaries · thin controllers · logic in services · persistence-only repositories |
| **API contract** | naming · versioning · envelope · pagination on collections · no unversioned breaking change |
| **Data** | keys · audit fields · soft delete · foreign keys and indexes · reversible migrations · no auto-sync in production |
| **Maintainability** | clear names · small functions · shallow nesting · no magic values · strict types |
| **Testing** | changed logic comes with tests · critical flows covered · no sleep-based or order-dependent tests |
| **Performance, caching, limits** | asked **together** for every endpoint the diff touches: bounded · cached per policy · authorized on every door to the same write · rate limited if public |
| **Spec fidelity** | only when step 2 found a spec. **Missing** · **Scope creep** · **Implemented but wrong** (the one that hides) |

Every finding gets a tier:

| tier | meaning |
|---|---|
| 🔴 **Blocking** | must fix before merge: confirmed security gap, missing authorization, data-corruption risk, undocumented breaking change, critical bug |
| 🟠 **Major** | should fix before release: missing tests, missing validation, N+1 or unbounded query, incomplete error handling |
| 🟡 **Minor** | optional: naming, readability, small refactors |
| 🔍 **Needs validation** | **no severity.** A source-grounded question blocked on a fact outside the repo |

### Step 5 — Apply safe fixes only

**Goal:** remove the noise without touching anything that needs a human.

| applied, then listed | reported, never applied |
|---|---|
| formatter output | logic or control flow |
| import order, unused imports | replacing loose types with real ones |
| `const` over `let` | adding or changing validation |
| quote, semicolon, trailing-comma style | renaming public symbols, endpoints, fields, enum values |
| | security fixes · architecture moves · schema and migration changes |

The test: a fix is safe only if a formatter or linter would make it **and** it cannot
change runtime behaviour or a public contract. The affected gate is re-run afterwards,
so the report reflects the fixed state.

### Step 6 — Emit the verdict

**Goal:** the same report shape every time, so it can be read in ten seconds.

```
# Quality Gate — feature/checkout vs develop · 6 files

## Summary
## Gates            Lint ✅ (3 auto-fixed) · Typecheck ✅ · Tests ❌ 2 failed · Build ⏭
## Spec fidelity    Missing / Scope creep / Implemented but wrong — each quoting the spec
## 🔴 Blocking       `path/file.ts:24` — defect — standard violated — smallest fix
## 🟠 Major
## 🟡 Minor
## 🔍 Needs validation
## Auto-fixes applied
## Verdict          Approve · Approve with Comments · Request Changes · Reject
```

It will **not** Approve when any of these hold:

- a Blocking finding exists;
- a **confirmed** security concern exists;
- a breaking API or schema change ships without versioning and documentation;
- a critical test is failing;
- an architecture standard is violated;
- the diff departs from its spec and nobody called the departure out.

When in doubt the verdict is **Request Changes**. A flagged non-issue costs a second
look, and a missed Blocking costs an incident. **Reject** is reserved for a
fundamentally wrong approach.

---

## The evidence contract, for security findings

See [`evidence-contract.md`](skills/quality-gate/references/evidence-contract.md). The
expensive failure in review is rarely a missed check. It is a claim that says more than
was measured: a suspicion written in the same ink as a proven defect. A week later
nobody can tell them apart, and the real one is buried. Three rules prevent it:

1. **A finding needs a boundary and a result.** Six rows: lower-trust principal ·
   accepted input · intended control · crossed boundary · affected resource · observed
   result. Without them it is a hardening note, not a security finding. Rejecting
   takes one line: name the principal and what they gain, or stop.
2. **`needs-validation` is a state, not a weak Blocking.** When the decisive fact sits
   outside the repo (a proxy header, an IAM policy, a provider default), the finding
   names that fact and a safe way to check it. It carries no severity.
3. **Severity cannot exceed demonstrated impact.** If the concrete damage cannot be
   stated, the severity is lower than it feels.

## Using the gate with security-audit

The gate reads **one** domain file from the security-audit skill when the diff calls for
it: auth, data isolation, cloud, client-side, resource exhaustion, or supply chain.
Reading a reference is not running an audit.

🔴 **Do not run the audit's six-phase workflow from inside the gate.** Its unit of cost
is an *agent invocation*. Even its `quick` profile runs four reconnaissance calls, a
hunter wave, a critic, and one or two verifiers per candidate. Schedule a full audit as
its own activity.

⚠️ Before a full run, know that the audit requires an OS-enforced sandbox (no network,
empty environment, hard resource limits) before it executes any target code. Most
machines do not have one, so a run there is **source-only** and every dynamic claim
comes back `needs-validation`. That is the honest result, and it is why the evidence
contract has to be in place *before* the audit rather than after.

---

## Layout

```
skills/quality-gate/
  SKILL.md                    the six steps
  references/
    evidence-contract.md      what makes a security claim count
    gates-and-fixes.md        finding and running the real gates; safe-fix policy
    backend-checklist.md
    frontend-checklist.md
    security-checklist.md
    go-live-checklist.md      release reviews only
templates/
  QUALITY-GATE.md             optional per-project config
bin/install.js                npm installer
install.sh                    shell installer
```

## Provenance

The gate grew out of a production review process and was rewritten here to be
project-neutral: no client names, no incident details, no internal hosts. What survives
is the method and the traps, which are general.

The evidence contract's three rules are adapted from Cloudflare's `security-audit`
skill (MIT). That skill is fetched from upstream at install time rather than vendored,
so it stays current and its licence and attribution travel with its own files.

## Releasing

Releases go to npm from GitHub Actions (`.github/workflows/release.yml`), with
[provenance](https://docs.npmjs.com/generating-provenance-statements), so every
published version links back to the commit that built it.

```bash
npm version patch          # or minor / major: bumps package.json and creates the tag
git push --follow-tags     # the v* tag triggers the release
```

The workflow refuses a tag that does not match `package.json`, checks that every
skill's `name` matches its directory, and installs from the packed tarball before it
publishes. Auth is npm trusted publishing (OIDC). A `NPM_TOKEN` secret in the `npm`
environment works as a fallback.

## Licence

MIT. See [`LICENSE`](LICENSE).

`security-audit` is © Cloudflare, MIT, and is not redistributed here. Both installers
clone it from upstream.
