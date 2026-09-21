# Mechanical gates and the safe-fix policy

How to find and run the repo's real gates, and exactly what may be auto-fixed. The
goal: let tooling catch mechanical problems so reading time goes to judgment, and only
ever apply a change that cannot alter behaviour or a public contract.

---

## Detect, don't assume

Read the project's manifest and run the scripts that **actually exist**. Do not run a
command that is not defined — report it as absent instead. Run long gates in the
background so review continues while they do.

```bash
# node
node -e "console.log(Object.keys(require('./package.json').scripts||{}).join('\n'))"
# make
grep -E '^[a-zA-Z_-]+:' Makefile
# python / rust / go
ls pyproject.toml tox.ini Cargo.toml Makefile go.mod 2>/dev/null
```

Then run each one that is a gate. Typical shapes:

| gate | look for |
|---|---|
| lint | `lint`, `lint:ci`, `check`, `ruff`, `clippy`, `golangci-lint` |
| format | `format`, `fmt`, `format:check` — prefer the **check** variant for reporting |
| typecheck | `typecheck`, `check`, `tsc --noEmit`, `mypy`, `svelte-check` |
| test | `test`, `test:unit`; integration and e2e separately |
| build | `build`, `compile` |

**Package manager and monorepo:** honour the lockfile (`pnpm`/`yarn`/`npm`/`bun`). In
a monorepo, scope to the changed workspace rather than building the world.

**Integration and e2e suites** often need a database, a cache, a browser, or a network
service. If one cannot run cleanly here, **say so and separate it from genuine
failures** — a false red costs as much trust as a false green.

---

## Three traps that each produced a false green

### 1. Never pipe a gate and then read `$?`

```bash
npm test | tail -5 ; echo $?      # ← this is TAIL's exit code. Always 0.
```

A failing suite reads as a pass. Redirect and read the tool's own status:

```bash
npm test > /tmp/test.log 2>&1 ; echo "exit=$?"
```

The same applies to a trailing `echo`, and to any wrapper that reports the status of
the last command in a chain rather than the gate's.

### 2. Run the gates that exist, not the ones you remember

Enumerate the manifest every time. A suite you never ran is not a suite that passed,
and the one you forgot is usually the one that would have gone red — a change that
adds a dependency to a class breaks the **unit** spec that hand-builds it while
integration tests, which wire the real thing, stay green.

### 3. The script is not always what CI runs

If CI invokes a binary with flags the script omits, the script can exit 0 while CI
fails — for example a docs or lint checker whose npm script lacks the `--check` flag
and therefore always succeeds. Compare the script body against the CI invocation.

---

## Reporting gate results

- Report the **real** counts from the output: `Tests: ❌ 2 failed (40 passed)`, with
  the first failing names. Never guess.
- A missing script is `⏭ no "lint" script found` — not a failure, and not a pass.
- **Sanity-check the test count against the baseline.** If the diff adds four tests,
  the total should move by four. A total that did not move, or moved by the wrong
  amount, means a suite silently did not run — which a green exit code will not tell
  you. Measure the baseline on the base branch rather than recalling it.

---

## Safe-fix policy

A fix is **safe to auto-apply** only if a formatter or linter would make it **and** it
cannot change runtime behaviour or a public contract.

### Auto-fix — apply, then list each one with its file

- The project formatter (`prettier --write`, `ruff format`, `gofmt`, `cargo fmt`).
- Linter autofix of safe rules: import ordering, unused-import removal,
  const-over-let, quote / semicolon / trailing-comma style, simple reflows.

### Report only — never auto-apply

- Any change to logic, control flow, or behaviour.
- Replacing loose types with concrete ones; adding or changing validation schemas.
- Renaming public symbols, endpoints, response fields, or enum values — a consumer
  depends on every one of them.
- Security changes: adding authorization, sanitisation, rate limiting.
- Architecture moves: taking logic out of a controller, introducing a worker path.
- Any schema or migration change.
- Deleting code that looks dead, unless you have confirmed it is unreferenced. A
  removed export can be a breaking change; when unsure, report instead of deleting.

### After auto-fixing

Re-run the affected gate so the report reflects the corrected state. If an autofix
touched something logic-adjacent, review that diff before keeping it.

---

## Proving a test is load-bearing

When the change adds a test, the report is stronger if the test is shown to be able to
fail. Neutralise the fix, confirm the test goes red **for the right reason**, restore
it. A test that stays green under a mutation of the code it claims to cover is proving
nothing, however well it reads.

Two things worth stating when you do this:

- **which** cases went red, counted — not "the test fails", but which ones and how
  many; and
- **how** they failed — an assertion mismatch and a hang are different evidence, and
  the one that matches the production symptom is the stronger claim.

Undo a mutation from a saved copy, never with a checkout that could take unrelated
work with it.
