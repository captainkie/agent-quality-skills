# Backend checklist

Server-side code: controllers/handlers, services, repositories, DTOs and schemas,
entities, migrations, workers and queues. Stack-neutral — the project's own standards
win where they differ.

---

## Layering

- **Handlers stay thin**: parse, authorize, delegate, shape the response. No business
  rules, no data access, no outbound integration calls in the request path.
- **Services own the rules**, and own the transaction boundary.
- **Repositories persist**, and do nothing else.
- Outbound integrations go where the project puts them — a queue, a worker, an outbox.
  A synchronous third-party call inside a request is an availability coupling; if the
  project has a pattern for this, not using it is an architecture violation.

## Routing

- **A literal path loses to a parameterised one unless it is registered first.**
  `/things/active` behind `/things/:id` is silently handled by `:id` — and the symptom
  is a type error deep in the handler, not a 404. Declare literals above parameters,
  and register a literal-path controller before the one owning the parent path.
- After adding a sub-path under an existing `:id` route, **call it once**. A route with
  no caller is not a route that works.

## API contract

- Consistent naming and versioning; one success and one error envelope across the API.
- **Collections are paginated**, and the response reports the true total so nothing is
  truncated silently.
- Every response shape documented. If the contract is published, a consumer builds from
  the document, not from the behaviour — **a documented field that is not sent, or a
  sent field that is not documented, is a defect in the contract**, and the cost lands
  on someone else's week.
- No breaking change without a version: removing a field, making a documented field
  optional or nullable, narrowing a type, or removing an undeprecated path.
- **Additive is the escape hatch.** A new field or a new endpoint is almost always
  allowed where a change to an existing one is not.

## Data and migrations

- Stable primary keys; audit columns; soft delete where the project uses it; consistent
  naming; foreign keys with the indexes to match.
- Migrations are reversible and ordered. No schema auto-sync outside development.
- **Moving a column moves its indexes.** A unique index defined on the old table
  disappears quietly when the column is recreated elsewhere — check the index list, not
  the column list.
- **Appending to a column with a CHECK constraint** can make an existing row
  unrepresentable. Read the constraint before widening a value.
- A uniqueness rule that depends on the current time cannot live in a partial index.
- **`INSERT … WHERE NOT EXISTS` is not a lock.** Under read-committed two concurrent
  transactions both pass it. Use an advisory lock or a real constraint.
- An upsert that emits an unconditional update will clobber a concurrent writer — make
  the update conditional when that matters.

## Money, time and identity

- **Money is an integer in the smallest unit**, or a decimal type — never a float.
  Sum it in the database, narrow it only at the boundary.
- **Timezone is a decision, not a default.** If the product's day boundary is not UTC,
  extracting a date part from a timestamp in the server's session timezone is wrong.
  Put the rule in one named helper.
- Identifiers that a person will be shown are never reissued after a race is lost.

## Performance, caching and limits

Ask the four **together** for every endpoint the diff touches, not only the one the
ticket named:

| | |
|---|---|
| **fast** | bounded query · no N+1 · indexed predicate · no `SELECT *` |
| **cached** | apply the project's policy for this data class rather than inventing one; bust on our own write; include any database or tenant discriminator **in the cache key** |
| **authorized** | the rule holds on every door reaching the same write |
| **limited** | public routes have a rate limit; outbound calls respect the partner's |

- **A consumer asking for the convenient shape is not a reason to drop a bound.** Give
  them what their screen needs *and* a ceiling, report the true total so nothing is cut
  silently, and say what the ceiling is.
- No per-row lookup inside a loop on a paginated endpoint.
- Check the query count on any list or dashboard route — those are the hot ones.

## Caching hazards

- **One cache instance shared across environments needs the environment in the key**,
  or a value from a dropped database is served to a live one.
- **Bump a version segment in the key when a value's shape changes**, or a stale entry
  deserialises into a shape the code no longer handles.
- A cache-aside helper with single-flight must not be re-entered on its own key by its
  own factory: it hands the factory the promise it is producing and the request never
  settles.

## Errors

- Fail closed. A degraded dependency should make the answer slower or narrower, never
  more permissive.
- Distinguish "the store is unavailable" (often survivable) from "the rule says no"
  (never survivable).

## Testing

- Changed business logic ships with a test. Missing is Major — Blocking for auth,
  money, permissions, and anything on a published contract.
- **Unit specs are where a new dependency surfaces.** A hand-built collaborator in a
  unit spec is the only written record of that class's dependency shape; an
  integration test wires the real thing and stays green.
- **Shared-database suites must seed what they assert on**, and purge it. A suite that
  reads another suite's leftovers passes locally and fails on a fresh database.
- **An assertion that loops over a list passes on an empty list.** Put a length
  assertion ahead of every such loop — without it the test cannot fail, which is the
  one thing a security test must be able to do.
- Fixtures must be unique **by construction**, not by luck. A derived random value with
  a small space collides eventually, and the failure surfaces inside a helper where it
  reads as a bug in the code under test.
