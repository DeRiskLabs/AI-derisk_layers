# Authoring Checklist — User Stories

## Placement & shape
- [ ] File under the owning boundary's `app/lib/user_stories/` — graph-facing stories at
      `apis/graph/app/lib/user_stories/graph/<domain>/<action>.rb`.
- [ ] Class `UserStories::Graph::<Domain>::<Action>`, inherits the relevant base
      (`UserStories::Graph::Base` / `<Engine>::BaseUserStory`) over `Layers::BaseLayer`.
- [ ] Inputs declared with `required` / `optional`.

## #call orchestration
- [ ] Reads as a sequence of guard clauses + one happy path.
- [ ] Find step looks up by public uuid through an identity-scoped query and guards
      missing records with `failure(errors: [...])` — off-limits records look absent
      (authorization is reach, not flags; no "not authorized" oracle).
- [ ] Engine-resident stories resolve use cases / query objects from the engine's
      registries — no static container-constant references.
- [ ] Reports via `success(<named_object>:)` / `failure(errors:)` — never returns a value,
      never a generic `result` key.
- [ ] Transactional writes delegated to a use case; complex reads to a query object.

## Boundaries
- [ ] No HTTP/GraphQL response shaping (that is the endpoint's job).
- [ ] No duplicated transactional logic that belongs in a use case.
- [ ] Detail pushed into private methods or collaborators.

## Verify
- [ ] Spec following [[testing-user-stories]] covers success, validation failure, and
      not-found (which covers off-limits records).
