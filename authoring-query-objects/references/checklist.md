# Authoring Checklist — Query Objects

## Placement & shape
- [ ] File at `app/lib/queries/<scope>/<name>_query.rb`; class `Queries::<Scope>::<Name>Query`.
- [ ] Shape matches the question: relation query or singular object-or-nil query.
- [ ] A relation query inherits `ApplicationQuery`, sets `relation_class 'Model'`, and
      passes its scope through `initialize(scope, **)` to `super(nil, **)`.
- [ ] A singular query remains a small PORO and injects its state-holding collaborator.

## Scoping
- [ ] The boundary (identity/firm/tenant) applied in private `build_relation_defaults!`.
- [ ] Callers cannot widen the scope (raw relation not exposed for re-scoping).
- [ ] `includes` declared for associations the caller will read (no N+1).
- [ ] `distinct` where joins can duplicate rows.
- [ ] Large SQL fragments extracted into small private methods.

## Boundaries
- [ ] Read-only: no writes, no side effects, no business logic.
- [ ] Relation refiners are chainable; a singular query returns its object or `nil`.

## Verify
- [ ] A dedicated query spec matches the shape: relation boundary/empty/chaining coverage,
      or singular object identity/absence coverage with an injected collaborator.
- [ ] The consuming endpoints' request/acceptance specs still cover their scoping and
      empty cases (the wiring) — they complement, not replace, the query spec.
