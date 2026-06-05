# Review Checklist — Query Object Specs


## Structure

- [ ] `require 'rails_helper'`; DB-backed via FactoryBot (no doubled relations/models).
- [ ] `subject(:query) { described_class.new(<scope>) }`.
- [ ] One `describe` per public entry; query call in `execute(:results)`.
- [ ] One expectation per `it`.


## Boundary coverage

- [ ] Scoping: in-scope AND out-of-scope records; `contain_exactly` on the result.
- [ ] Empty case: out-of-scope records exist, result is empty.
- [ ] Every composed `where`/`join` condition has a context with a record failing exactly
      that condition.


## Interface coverage

- [ ] Every refining method (incl. custom ones) proves BOTH halves of its contract:
  - [ ] identity: returns the object under test (`expect(...).to be(query)`).
  - [ ] mutation: the relation received the intended message (spy via the `relation:`
        option + `have_received`), or the DB-backed result reflects it.
- [ ] `order` applies the sort (assert first/last of the result).
- [ ] `page`/`per` limit the result.
- [ ] `per` before `page` raises `PaginationError` (block expectation).


## Avoid

- [ ] No assertions on SQL strings or relation internals — returned records only.
- [ ] No stubbing the model or the relation.
- [ ] Exclusion and emptiness covered, not just the happy scope.
