# Authoring Checklist — GraphQL Queries

- [ ] Under `resolvers/<domain>/<name>.rb`, inherits `ApplicationResolver`; plural class for
      the list, singular for one record.
- [ ] `description` present; every `argument` has a description.
- [ ] `type ..., null:` declared (array type for lists).
- [ ] Lookup arguments only (e.g. `:id, Types::Base::UuidType`) — no identity/authorization
      arguments.
- [ ] `user_story 'user_stories/graph/<domain>/<fetch|fetch_all>'` declared; story exists.
- [ ] `user_story_arg :current_identity` (context-derived).
- [ ] `on_success` receives the named object (`articles:` / `article:`) and returns it
      directly — no payload hash, never a generic `result` key.
- [ ] `on_failure(errors:)` maps to `GraphQL::ExecutionError`s.
- [ ] Scoping implemented in the user story, driven by `current_identity` — not in the
      resolver.
- [ ] Wired in `QueryType` via `resolver:`.
- [ ] Acceptance spec written per [[testing-graphql]] (including empty + scoping cases);
      NO unit spec for the resolver.
