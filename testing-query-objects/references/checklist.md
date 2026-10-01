# Review Checklist — Query Object Specs


## Structure

- [ ] `require 'rails_helper'` and one public query action in `execute(:results)`.
- [ ] Relation query: DB-backed via FactoryBot; `described_class.new(<scope>)`.
- [ ] Singular query: injected state holder; no database or fake relation.
- [ ] One `describe` per public entry; query call in `execute(:results)`.
- [ ] One expectation per `it`.


## Boundary coverage

- [ ] The checks below apply to relation queries.
- [ ] Scoping: in-scope AND out-of-scope records; `contain_exactly` on the returned collection.
- [ ] Empty case: out-of-scope records exist, result is empty.
- [ ] Every composed `where`/`join` condition has a context with a record failing exactly
      that condition.


## Interface coverage

- [ ] A singular query returns the object by identity (`be`) or `nil`, matching its contract.
- [ ] A singular query spec does not assert the state holder's reader message (an outgoing query).
- [ ] Every refining method (incl. custom ones) proves BOTH halves of its contract:
  - [ ] identity: returns the object under test (`expect(...).to be(query)`).
  - [ ] mutation: the relation received the intended message (spy via the `relation:`
        option + `have_received`), or the DB-backed result reflects it.
- [ ] `order` applies the sort (assert first/last of the returned collection).
- [ ] `page`/`per` limit the returned collection.
- [ ] `per` before `page` raises `PaginationError` (block expectation).


## Avoid

- [ ] No assertions on SQL strings or relation internals — returned records only.
- [ ] No stubbing the model or the relation.
- [ ] Exclusion and emptiness covered, not just the happy scope.
- [ ] No relation wrapper or relation shared examples around a singular retained object.
