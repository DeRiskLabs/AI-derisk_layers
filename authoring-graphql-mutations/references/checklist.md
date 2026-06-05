# Authoring Checklist — GraphQL Mutations

- [ ] Under `mutations/<domain>/<action>.rb`, inherits `ApplicationMutation`.
- [ ] `description` present; every `argument` and `field` has a description.
- [ ] Arguments are client-supplied values only, with project scalar types.
- [ ] Payload is `field :<resource>` + `field :errors, [Types::Base::ErrorType]`.
- [ ] `user_story 'user_stories/graph/<domain>/<action>'` declared; story exists at that path.
- [ ] `user_story_arg`s map to private readers on the base (context-derived), not client args.
- [ ] `on_success(<resource>:)` returns `{ <resource>:, errors: [] }`.
- [ ] `on_failure(errors:)` returns `{ <resource>: nil, errors: execution_errors_for(errors) }`.
- [ ] Registered in `MutationType` (`field :<action>_<resource>, mutation: ...`).
- [ ] No business logic anywhere in the mutation.
- [ ] Acceptance spec written per [[testing-graphql]]; NO unit spec for the mutation.
