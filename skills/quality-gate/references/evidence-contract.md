# Evidence contract for security findings

A checklist answers *does the code do X?* This file answers the other half: **what it
takes for a claim about X to count.**

It exists because the expensive failure in review is rarely a missed check. It is a
claim that says more than it measured — a suspicion written in the same ink as a
proven defect, so that a week later nobody can tell them apart, and the real one is
buried in the pile.

The three rules are adapted from Cloudflare's `security-audit` skill
(MIT, <https://github.com/cloudflare/security-audit-skill>), which is the companion to
this gate. See "Where this gate stops" at the bottom.

---

## Rule 1 — A finding needs a boundary AND a result

Fill in all six, or it is not a security finding:

| | |
|---|---|
| **lower-trust principal** | who is doing this — an anonymous caller, a basic user, a suspended account, another tenant's admin |
| **accepted input or action** | what they send or do |
| **intended control** | the guard or rule that is supposed to stop it |
| **crossed boundary** | which line that control was drawing |
| **affected principal or resource** | whose data or capability moves |
| **observed or owner-observable result** | what actually happens — not what could |

### What this excludes, on purpose

- **A missing best practice with no principal and no crossed boundary.** "Tokens are
  kept in `localStorage`" names nobody and crosses nothing on its own. It becomes a
  finding when you can say who reads them and what they then reach. Until then it is
  a hardening note, and filing it as a security finding makes the real ones harder to
  see.
- **Guessed deployment behaviour.** A proxy, provider default, browser policy or IAM
  rule that is not in the repository is not evidence in either direction. That is what
  Rule 2 is for.
- **A generic crash with no security outcome.**
- **Self-impact.** A caller degrading only their own session has not crossed a
  boundary.

---

## Rule 2 — `needs-validation` is a STATE, and it carries no severity

Three states, and keeping them apart is the whole point:

| state | means |
|---|---|
| **confirmed** | the six rows above are filled in from source, or from a bounded local run |
| **needs-validation** | a specific, source-grounded hypothesis whose **decisive fact is outside** what the repository can show |
| **rejected** | traced, and the boundary holds |

🔴 **`needs-validation` is not "a confirmed finding I am less sure about".** It gets
**no severity at all** — not a lower one. A severity on an unverified item is how a
list of *things to go and check* silently becomes a list of *holes*.

A `needs-validation` entry must carry:

1. the exact missing fact (`is the load balancer setting X-Forwarded-For, or is the
   app trusting a client-supplied one?`), and
2. a safe way to establish it — an owner-observable check or a bounded local test.
   Never a probe against production or shared infrastructure.

**Write it down even when you cannot resolve it.** An unrecorded question comes back
as an incident; a recorded one comes back as a task.

---

## Rule 3 — Severity cannot exceed demonstrated impact

| | |
|---|---|
| **critical** | an unauthenticated actor gains code execution, full data-store access, or takeover of arbitrary accounts |
| **high** | an explicit control is **fully defeated** with real consequence — auth bypass, cross-tenant read or write, stored script execution affecting other users, authenticated code execution, unauthenticated remote stop of a shared service |
| **medium** | a real boundary violation with limited blast radius or uncommon preconditions |
| **low** | non-secret internals disclosed, or sustained effort for minimal gain |
| **informational** | confirmed but minimal — useful mainly as a step inside a larger finding |

**The high/medium line:** does the demonstrated result *fully defeat* the control, or
only weaken it?

**If you cannot state the concrete damage, the severity is lower than it feels.**

> This governs how a finding is **described**. It does not soften the merge rule: a
> confirmed security gap is Blocking wherever it lands on this table.

---

## Rule 4 — Recommend the smallest effective fix

Name the invariant the code must enforce, and the narrowest change that enforces it
**at the last trusted decision point**. A repository-relative edit plus a regression
test, not generic hardening advice.

If the same rule is enforced at several doors, say so — a fix at one door while the
others still reach the same write is a fix that moves the defect rather than closing
it.

---

## Where this gate stops, and the audit begins

This gate reviews **a diff**. A security audit surveys **a system**, and they are not
the same activity or the same cost.

Use the companion skill's **guidance mode** from here: when the diff calls for it,
read the ONE domain file that matches. Reading a reference is not running an audit.

| the diff touches | read |
|---|---|
| auth, sessions, tokens, CORS, headers, route guards | `WEB-PROTOCOL-AND-AUTH.md` |
| tenancy, soft delete, exports, retention, cross-account reads | `DATA-ISOLATION-AND-LIFECYCLE.md` |
| cloud runtime, IAM, buckets, caches, manifests, environment | `CLOUD-AND-DEPLOYMENT.md` |
| rendering user input, uploads, CSP, client-side state | `CLIENT-SIDE.md` |
| pagination, unbounded queries, rate limits, timeouts | `RESOURCE-EXHAUSTION-AND-AVAILABILITY.md` |
| dependencies, build, release, signing | `SUPPLY-CHAIN-AND-RELEASE.md` |

🔴 **Do NOT run that skill's six-phase workflow from inside this gate.** Its unit of
cost is an *agent invocation*: even its `quick` profile is four reconnaissance calls
plus a hunter wave, a critic, and one or two verifiers per candidate. A per-change
gate cannot afford that, and the skill says so itself — loading it does not authorize
the workflow.

**Schedule full audit mode as its own activity**, ideally before an external
penetration test so the cheap findings are already fixed.

⚠️ **Know this before the run, not during it:** that skill requires an OS-enforced
sandbox — no network, empty environment, hard CPU/memory/wall-clock limits — before
executing any target code, and states that without every control you do not execute
it. Most machines do not have one. A run without it is **source-only**, and every
dynamic claim comes back `needs-validation`. That is the honest result, and it is
exactly why Rule 2 has to be in place *before* the audit rather than after it.

---

## Anti-patterns

1. A checklist deviation presented as a vulnerability.
2. Defence-in-depth advice with no reachable boundary violation.
3. Probing live or shared environments where bounded local evidence would do.
4. Guessing provider, proxy, browser, identity or deployment behaviour absent from source.
5. Treating same-principal authority or self-impact as a crossed boundary.
6. Reporting an effect stronger than the one observed.
7. Assigning a severity to a `needs-validation` record.
8. Letting the prose and the structured findings disagree.
