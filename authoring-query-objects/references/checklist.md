# common_agent_skills/derisk_layers/authoring-query-objects/references/checklist.md


# Authoring Checklist — Query Objects

## Placement & shape
- [ ] File at `app/lib/queries/<scope>/<name>_query.rb`; class `Queries::<Scope>::<Name>Query`.
- [ ] Inherits `ApplicationQuery` (the app's `Layers::BaseQueryObject` evolution).
- [ ] `relation_class 'Model'` set.
- [ ] `initialize(scope, **)` stores the scope and calls `super(nil, **)`.

## Scoping
- [ ] The boundary (identity/firm/tenant) applied in private `build_relation_defaults!`.
- [ ] Callers cannot widen the scope (raw relation not exposed for re-scoping).
- [ ] `includes` declared for associations the caller will read (no N+1).
- [ ] `distinct` where joins can duplicate rows.
- [ ] Large SQL fragments extracted into small private methods.

## Boundaries
- [ ] Read-only: no writes, no side effects, no business logic.
- [ ] Returns chainable query / relation; `order`/`page`/`per` left to the caller.

## Verify
- [ ] A dedicated query spec exists: scoping boundary (in-scope returned, out-of-scope
      excluded, via `contain_exactly`), empty case, each join/condition branch, and
      chaining (`order`, `page`/`per`).
- [ ] The consuming endpoints' request/acceptance specs still cover their scoping and
      empty cases (the wiring) — they complement, not replace, the query spec.
