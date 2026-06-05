# Authoring Checklist — Use Cases

## Placement & shape
- [ ] File at `app/lib/use_cases/<domain>/<action>.rb`; class `UseCases::<Domain>::<Action>`.
- [ ] Inherits from `ApplicationUseCase` (or the engine-local base) which inherits `Layers::BaseLayer`.
- [ ] Inputs declared with `required` / `optional`; prefers `required :form`.
- [ ] Needed form methods exposed via `delegate`.

## #call
- [ ] Represents exactly one action (no "and").
- [ ] Validity guard first: `return failure(...) unless valid?`.
- [ ] Writes wrapped in `ActiveRecord::Base.transaction`.
- [ ] Success via `success(<payload>:)`; expected failures via `failure(<payload>:)`.
- [ ] Persistence errors rescued and converted to `failure` (no raising out of `#call`).

## Boundaries
- [ ] No HTTP/GraphQL/controller knowledge.
- [ ] No reads that belong in a query object.
- [ ] No orchestration of other use cases (that is a user story).
- [ ] Keyword payloads are stable and meaningful.

## Verify
- [ ] A spec exists following [[testing-use-cases]] covering success, validation failure, and
      persistence failure.
