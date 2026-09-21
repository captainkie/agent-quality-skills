# Go-live / release-readiness checklist

Use this **only** when asked for a release, go-live or production-readiness review —
never for a routine per-change review.

Produce a report grouped by priority, each item ✅ / ❌ / ⏭ (n/a) with a one-line note,
then a **Go / No-Go**. Any failing P0 → **No-Go**.

> ⚠️ **Mark ✅ only from evidence you gathered in this run.** An item copied forward
> from a previous release, or taken from a status page, is ⏭ with a note saying who
> owns it — not ✅. The single most common way a release checklist misleads is a tick
> that records somebody's memory rather than a check.

---

## P0 — must pass

**Security** — authentication verified · authorization verified on every protected
action · no secret in source or logs · production secrets in a secret store ·
input validation · upload validation · rate limits on public routes · CORS reviewed ·
transport encrypted · credentials and tokens absent from logs.

**Data** — production backup taken **and a restore tested** · every migration reviewed
and run both directions · constraints and indexes verified · connection pool sized ·
rollback documented.

**Infrastructure** — environment and variables verified · images built and versioned ·
health checks answering · certificates valid · DNS correct · firewall reviewed.

**Observability** — service, data-store and worker monitoring on · error alerting on ·
**alert delivery tested**, not just configured.

**Logging** — structured · correlation ids present · no sensitive field logged.

**Async and integrations** — queues, retries and dead-letter paths configured · workers
connected · each external integration's credentials, connectivity, retry and failure
handling exercised.

**Application flows** — every critical user journey tested end to end, named
individually rather than as a group.

**Deployment** — release notes · deployment plan · **rollback plan** · named owner ·
business approval.

**Delivery channel** — ⚠️ the one most often missing from a plan that tracks only code
and data. Can the built artefact actually reach users? Store or distribution account in
good standing, signing identity valid, build toolchain at the version the store
requires, and somebody named as its owner. Verify it by pushing a build through the
real path, not by assuming — this is regularly discovered on the day of release,
because nothing in the development process touches it.

---

## P1 — should pass

**Testing** — unit, integration and end-to-end green · regression done · user
acceptance done.

**Performance** — response times measured · slow queries reviewed · N+1 checked ·
indexes confirmed · queue throughput reviewed. Measured numbers, not impressions.

**Localisation** — every locale's content verified · switching and fallback verified.

**Documentation** — API reference regenerated **and published** — the generated file in
the repository is not what consumers read · deployment docs current.

**Auditability** — audit log covers the actions that matter, including the value
before a change, and someone can read it.

**CI/CD** — build, test, deploy and rollback pipelines each exercised.

---

## P2 — nice to have

Caching and asset optimisation · runbook, on-call and incident docs · disaster-recovery
rehearsal with a stated objective · capacity and scaling reviewed.

---

## Final Go / No-Go

- [ ] All P0 complete
- [ ] Outstanding risks written down, with an owner each
- [ ] Stakeholders informed
- [ ] Rollback approved

**Recommendation: Go / No-Go**, with justification.

> 🔒 **Do not publish an open security item.** A vulnerability already fixed is good
> material for a release note — it shows the review is real. One still open tells a
> reader where to push before it is closed. Track those internally and say only that
> internal security follow-ups exist, if it must be mentioned at all.
