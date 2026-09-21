# Quality gate — project configuration

Copy this to your repository root as `QUALITY-GATE.md` and fill it in. It is
**optional**: the gate works without it, using the bundled checklists and whatever
scripts your manifest defines. This file is how a project overrides those defaults and
records the traps a reviewer cannot infer from the code.

Delete every section you do not need. An empty heading is worse than no heading — it
reads as "nothing here", which is a claim.

---

## Standards

Where the written standards live, if not in one of the conventional locations:

```
docs/standards/
```

Which ones cover what, if it is not obvious from the filenames.

---

## Lanes

If not every change needs the same depth of review, say so here — otherwise the gate
treats them all as full.

| lane | what falls in it | when the gate runs |
|---|---|---|
| **full** | auth · money · permissions · migrations · anything on a published contract | before merge |
| **fast** | internal screens · copy · docs · refactor with no behaviour change · test-only | batched |

> When unsure, it is **full**. A change that looks internal but alters what an external
> consumer renders is full lane.

---

## Branches and merge rules

```
feature → develop → staging → main
```

- Feature into the integration branch: **squash**.
- Every promotion between long-lived branches: **merge commit, never squash.** Squashing
  a promotion makes the two branches look like they never met, and every promotion
  afterwards shows the whole diff with conflicts, permanently.
- Protected branches: …

---

## Gates the project actually has

List the commands, including any that the manifest does **not** expose as a script —
those are the ones a reviewer misses.

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

⚠️ Note any script whose body differs from what CI runs. A checker whose npm script
omits its `--check` flag exits 0 always, and reports as a passing gate.

---

## Traps specific to this codebase

The highest-value section, and the only one nothing else can supply. Each entry is a
thing that has been **wrong while looking right** here.

Write each one as: *the symptom* → *the actual cause* → *what to check instead*.

- …

---

## What must not be published

Anything the gate should never write into a public artefact — open security items,
internal hostnames, customer identifiers.

- …
