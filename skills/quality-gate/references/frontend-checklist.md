# Frontend checklist

UI code: components, pages, route loaders, forms, client state, and anywhere user
input is rendered. Stack-neutral — the project's own standards win where they differ.

---

## The frontend is never authoritative

- Every rule the UI expresses is also enforced on the server. A hidden button is UX,
  not a permission.
- **A control that reports success and changes nothing is Blocking**, not Minor — even
  when the broken behaviour predates the change. Adding the control is what makes it
  reachable, so the change owns it.
- Where the server refuses, show **the server's own reason**. A message invented in the
  client drifts from the rule the server actually enforces, and then two places disagree
  about what happened.

## Write mappers — the blind spot

The single highest-value area in a UI review, because a mocked or faked API layer
**cannot see it**: a mock never receives a request body, so a mapper that *drops* a
field and one that *clears* it look identical from the mock.

- **`undefined` is not "empty" — it is "don't touch this".** Serialisation drops the
  key, so a partial update leaves whatever the record had. If the intent is *clear this
  field*, send the explicit empty value the API accepts.
- **Never send an empty string to mean empty** where the API's empty is null: `""` is
  accepted and stored, then reaches consumers as a string rather than an absence, and
  downstream renderers throw on it.
- **Absent and empty-collection are different requests.** If the API treats a missing
  key as "leave alone" and an empty array as "remove all", the mapper must be able to
  express both, and the difference must be a distinct code path — not a falsy check.
- **Anything mapping UI state onto a request body needs a test that stubs the transport
  and asserts on the serialised body.** Not on the mock. That test is the only thing
  that can distinguish the two failures above.

## Read mappers

- Map at the boundary; do not pass a raw response through typed as the domain object.
  A cast type-checks and validates nothing, and the field you add next arrives unmapped.
- Decide what a malformed value defaults to, and pick the default that **fails toward
  the recoverable side** — an over-permissive screen the server then refuses beats a
  screen that cannot be used.

## Loading, empty and failure are three states, not two

- **A failed read is not an empty result.** Many data libraries report "not loading"
  once a request errors, so keying only on a loading flag draws "there is nothing here"
  over data that exists and the user cannot tell.
- A paused query — offline, or a network-mode guard — is a fourth case that looks like
  neither. Use an explicit "has anything arrived?" check rather than inferring it.
- Put the error branch **first**, so a 403 reads as "you may not see these" rather than
  "there are none".

## Lists and pagination

- **One request with no limit is not "the whole list" — it is the first page,
  silently.** Either page through to the server's reported total, or ask for a bound
  and show it.
- If the screen prints a count, it must come from a **different source** than the array
  it labels. A count taken from the rendered array agrees with the screen by
  construction and can never catch a truncation.

## Rendering user input

- Escape everything that came from a person. Where a page renders both authored content
  and submitted content, **check which path each field takes** — the usual defect is
  one field crossing from the escaped path to the authored one, and it is stored XSS on
  a page colleagues read.

## Forms

- Validate with the same rules the server uses, and treat the server as the decider.
- Trim before length rules, not after, or whitespace passes a minimum and stores empty.
- Surface field-level server errors next to their fields.

## Internationalisation

- No user-visible string hardcoded when the project has a message catalogue.
- Adding a key means adding it to **every** locale; a missing translation should be
  visible in a check, not at runtime.

## Accessibility and layout

- Interactive controls are reachable by keyboard and carry an accessible name.
- Icon-only buttons need a label.
- **A page that loads is not a page that renders.** Every link resolving is not evidence
  of a working screen — a layout can collapse to an unusable strip while every request
  returns 200. When a page is reported broken, open it and measure the container.

## Testing

- Test the mapping and the state machine; do not re-test the framework.
- **A test of on-screen copy must anchor the claim it makes.** Asserting a string exists
  proves the string exists, not that it is shown in the right state.
- Prefer a walk through the real screen for a flow bug; an assertion can agree with a
  broken screen when both were written from the same wrong assumption.
