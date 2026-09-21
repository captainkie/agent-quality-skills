# Security checklist (cross-cutting)

Read **`evidence-contract.md` first** if you are about to write a finding. This file
is the *what to look at*; that one is *what makes a claim count*.

Security is never deferred: a **confirmed** gap is Blocking, full stop. A suspicion is
`needs-validation` and carries no severity.

Principles: least privilege · defence in depth · secure by default · explicit
authorization · fail securely. Never trust user input, client-side validation, or an
external integration. **Every control is enforced server-side.**

---

## Authentication

- Short-lived access credentials; refresh rotated; signature **and** expiry verified.
- Login, logout, refresh and password-reset paths all exist and all agree.
- Passwords hashed with a memory-hard or adaptive KDF (argon2, bcrypt, scrypt) — never
  plaintext, never a bare fast hash, never logged.
- A token minted for one purpose must not be accepted for another. If the system issues
  scoped or single-purpose tokens, the verifier checks the scope, not just the
  signature.

## Authorization

- Enforced on the **server**, at route *and* resource level. A frontend check is UX.
- **Ask it as: who writes this value, who can change it, and who can see it?** — not
  "does the check exist?". The check usually exists.
- **Every door that reaches the same write must carry the same rule.** A guard on the
  endpoint in the ticket, with a sibling route reaching the same mutation unguarded, is
  a gap — and it is the most common one.
- Hiding a control in the client is not hiding the data: if it is on the wire, it has
  leaked.

## Input validation and injection

- Validate body, query, path params and uploads at the boundary, with a schema.
- **SQL:** parameterised queries only. String-interpolated SQL with user input is
  Blocking.
- **XSS:** escape on output; never render untrusted HTML. Where a page renders both
  authored content and user-submitted content, **check which path each field takes** —
  the usual defect is one field crossing from the escaped path to the authored one.
- **SSRF:** never fetch a user-supplied URL without validating scheme and host and
  blocking internal ranges.
- **Deserialisation and templating:** no user input reaching an evaluator.

## Rate limiting and abuse

- Public and unauthenticated routes are limited. Login, one-time codes and
  password-reset need the tightest.
- Outbound calls respect the **partner's** limit too, not only ours.
- A counter that does not move for one class of caller is itself an oracle — check that
  a refusal path and a success path are not distinguishable by timing or by a side
  effect when the intent is that they should not be.

## File upload

- Validate size, declared type **and** actual content; allow-list rather than deny-list.
- Never execute an upload; store outside any executable path; serve private files
  through a signed, expiring URL rather than a public one.
- **Keep public and private storage physically separate**, and make the separation
  structural — two ports or two buckets, not one flag. A flag is one wrong argument
  away from publishing an identity document; a missing method is not.

## Secrets

- No secret in source: signing keys, database and cache passwords, integration
  credentials, API keys. A hardcoded secret is Blocking.
- Never commit environment files, private keys or tokens. Run a secret scanner over
  history, not just the diff.
- A default value for a secret that is only refused in production is a secret in source.

## Logging

- Structured, with a correlation id and the acting principal.
- **Never log** passwords, tokens, authorization headers, one-time codes, full card or
  identity numbers. Logging any of these is Blocking.
- Log the id, not the person: a user id is fine, an email address in a log is a
  retention problem.

## Error handling

- No stack trace, SQL, internal path or secret in a response. Generic message out,
  detail to the log.
- **The message must be true.** A handler that answers "invalid credentials" from a
  path that never checked a credential sends the client to re-prompt for something that
  was correct, and sends whoever reads the log hunting a bug that does not exist.

## Infrastructure, when visible in the diff

- Transport encrypted; only required ports exposed.
- Data stores authenticated and not publicly reachable.
- If the app trusts a forwarded client IP, something upstream must be setting it — if
  that cannot be established from the repository, it is `needs-validation`, with the
  consequence stated (per-IP limits and any IP kept as evidence are wrong).

## Dependencies

- No unused packages. Known-vulnerability check before release. A pinned-backwards
  version to dodge a break can drag in advisories — check before pinning down.

---

## Quick triage

**Blocking** — missing authn/authz on a reachable action · secret or token in code or
logs · interpolated SQL · untrusted HTML rendered · arbitrary URL fetched · uploads
executed or exposed · responses leaking internals · **a control that reports success
and changes nothing** (adding the button is what makes it reachable, so the change owns
it, even when the broken behaviour predates it).

**Major** — missing rate limit on a sensitive public route · weak upload validation ·
missing validation not yet exploitable · missing audit trail on a sensitive action.

**Minor** — hardening suggestions, log-field completeness, naming.

**Needs validation** — anything whose decisive fact is a proxy, provider, identity or
deployment behaviour not present in the repository. No severity. State the missing fact
and a safe way to check it.
