# agent-quality-skills

A pre-ship **quality gate** skill for coding agents, plus a one-command install that
brings Cloudflare's **security-audit** skill along beside it.

Two skills that do different jobs and are easy to confuse:

| | reviews | cost | when |
|---|---|---|---|
| **quality-gate** (here) | a **diff** | one agent, minutes | every change, before merge |
| **security-audit** ([Cloudflare](https://github.com/cloudflare/security-audit-skill)) | a **system** | many agents, hours | scheduled, before a pen test |

The gate reviews and applies mechanically-safe fixes. The audit surveys and reports —
it does not modify source. Neither replaces the other.

## Install

```bash
npx skills add captainkie/agent-quality-skills        # the gate
npx skills add cloudflare/security-audit-skill        # the audit, from upstream
```

This uses the [skills CLI](https://skills.sh). It detects your agents (Claude Code,
Cursor, Codex, and others) and asks where to install. Common variants:

```bash
npx skills add captainkie/agent-quality-skills -g     # user-level, every project
npx skills add captainkie/agent-quality-skills -a claude-code -g -y
npx skills update quality-gate                        # pull the latest version
npx skills remove quality-gate
```

### Without npx

`install.sh` installs both skills in one command, for machines without Node or when you
want both together:

```bash
curl -fsSL https://raw.githubusercontent.com/captainkie/agent-quality-skills/main/install.sh | bash
```

Or from a clone:

```bash
./install.sh                # both, into ~/.claude/skills
./install.sh --gate-only    # just the gate, no network needed
./install.sh --project      # into ./.claude/skills, for one repo
./install.sh --dir <path>   # somewhere explicit
```

Re-running updates in place. Nothing outside the chosen skills directory is written,
and no shell profile is touched.

Then, optionally, copy `templates/QUALITY-GATE.md` into your repo root and fill it in.

## What the gate does

Six steps, in order:

1. **Resolve the standards** — your project's written docs if they exist, the bundled
   checklists if they do not. Yours win where they conflict.
2. **Determine scope** — the diff, plus what it affects; and *what the change was
   supposed to be*, from the spec, issue or PR it came from.
3. **Run the repo's real gates** — read the manifest, run what exists, report the
   actual counts.
4. **Audit against the standards** — correctness, security, architecture, contract,
   data, maintainability, testing, performance, and spec fidelity.
5. **Apply safe fixes only** — formatter and linter autofix. Never logic, types,
   validation, public names, security, architecture or schema.
6. **Emit a verdict** — Blocking / Major / Minor, a separate no-severity
   **Needs-validation** list, and Approve / Approve with Comments / Request Changes /
   Reject.

### Two things it does that a generic review does not

**It checks the diff against its spec.** Good code can fail this. The author and the
reviewer are usually the same context, and a spec written an hour earlier stops being
read — so the characteristic failure is code that looks entirely correct on its own and
is only wrong *next to the spec*. The gate asks three questions: what is **missing**,
what is **scope creep**, and what is **implemented but wrong** — the last being the one
that hides.

**It holds a security finding to an evidence contract.** See
[`evidence-contract.md`](skills/quality-gate/references/evidence-contract.md):

- A finding needs a **boundary and a result** — six named rows, or it is a hardening
  note rather than a security finding.
- **`needs-validation` is a state, not a weak Blocking, and it carries no severity.**
  When the decisive fact is outside the repository — a proxy header, an IAM policy, a
  provider default — that is what you write, with the missing fact and a safe way to
  check it.
- **Severity cannot exceed demonstrated impact.** If you cannot state the concrete
  damage, it is lower than it feels.

Those three exist because the expensive failure in review is rarely a missed check. It
is a claim that says more than it measured — a suspicion written in the same ink as a
proven defect, so a week later nobody can tell them apart and the real one is buried.

## Using the two together

The gate reads **one** domain file from the security-audit skill when the diff calls for
it — auth, data isolation, cloud, client-side, resource exhaustion, supply chain.
Reading a reference is not running an audit.

🔴 **Do not run the audit's six-phase workflow from inside the gate.** Its unit of cost
is an *agent invocation*: even its `quick` profile is four reconnaissance calls plus a
hunter wave, a critic, and one or two verifiers per candidate. The skill says so itself
— loading it does not authorize the workflow. Schedule a full audit as its own
activity.

⚠️ And know this before a full run: that skill requires an OS-enforced sandbox — no
network, empty environment, hard resource limits — before executing any target code,
and states that without every control you do not execute it. Most machines do not have
one, so a run is **source-only** and every dynamic claim comes back
`needs-validation`. That is the honest result, and it is why the evidence contract has
to be in place *before* the audit rather than after.

## Layout

```
skills/quality-gate/
  SKILL.md
  references/
    evidence-contract.md      what makes a security claim count
    gates-and-fixes.md        finding and running the real gates; safe-fix policy
    backend-checklist.md
    frontend-checklist.md
    security-checklist.md
    go-live-checklist.md      release reviews only
templates/
  QUALITY-GATE.md             optional per-project config
install.sh
```

## Provenance

The gate grew out of a production review process and was rewritten here to be
project-neutral: no client names, no incident details, no internal hosts. What survives
is the method and the traps, which are general.

The evidence contract's three rules are adapted from Cloudflare's `security-audit`
skill (MIT). That skill is fetched from upstream at install time rather than vendored,
so it stays current and its licence and attribution travel with its own files.

## Licence

MIT — see [`LICENSE`](LICENSE).

`security-audit` is © Cloudflare, MIT, and is not redistributed here; `install.sh`
clones it from upstream.
