# Shared Checklist — GraphQL Layer


## Placement & shape

- [ ] Endpoints under `apis/graph/app/graphql/graph/{mutations,resolvers}/<domain>/`.
- [ ] Types under `apis/graph/app/graphql/graph/types/<domain>/`; base types under `types/base/`.
- [ ] Concrete endpoints inherit `ApplicationMutation`/`ApplicationResolver` (the only
      places `Layers::Graphql::BaseEndpoint` is included).
- [ ] User stories inside the engine, under `apis/graph/app/lib/user_stories/graph/<domain>/<action>.rb`.


## Delegation & trust

- [ ] `user_story '...'` declares the behaviour; the endpoint adds nothing else.
- [ ] `user_story_arg`s pull trusted values (identity) from `context`, not client input.
- [ ] `on_success`/`on_failure` only shape the payload — no domain logic.


## Types & errors

- [ ] Types are pure `field` declarations with descriptions; project scalars
      (`UuidType`, ISO8601) used.
- [ ] Errors travel as `Types::Base::ErrorType` (`message` + `path`); mapping via the
      base's `execution_errors_for`.
- [ ] Mutations registered in `MutationType`; resolvers wired in `QueryType` via `resolver:`.


## Testing strategy

- [ ] Acceptance spec following [[testing-graphql]] covers success + failure (and auth).
- [ ] NO unit specs for concrete mutations, resolvers, or types.
- [ ] Behaviour unit-tested in the user story spec ([[testing-user-stories]]).
- [ ] Machinery (`Layers::Graphql::BaseEndpoint`, DSL mixins) tested in the layers gem
      ([[testing-layers-base-classes]]).
