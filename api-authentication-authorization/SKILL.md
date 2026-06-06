---
name: api-authentication-authorization
title: API Authentication and Authorization
description: Where auth lives in the API engines - authentication at the engine edge (Doorkeeper concern for REST, context hash for GraphQL), authorization as identity scoping inside user stories. Use when wiring auth for an endpoint or deciding where a permission check goes.
category: architecture
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - authentication
  - authorization
  - current_identity
  - protect an endpoint
  - permission check
anti_triggers:
  - identity domain modelling itself
user_invocable: true
last_reviewed_at: 2026-06-06
---


# API Authentication and Authorization

Two different questions, two different homes:

- **Authentication** ("who is this?") happens once, at the API engine's edge.
- **Authorization** ("what may they touch?") is identity scoping inside the layer
  objects — primarily user stories.

`current_identity` is the actor vocabulary everywhere (never `current_user`).


## Authentication at the Edge

### REST engine (`apis/v1`)

An engine-owned concern included by the engine's `ApplicationController`:

```ruby
module V1
  module Authorization
    extend ActiveSupport::Concern

    included do
      before_action :doorkeeper_authorize!
    end

    def current_user_account
      return unless doorkeeper_token
      @current_user_account ||= UserAccount.find(doorkeeper_token.resource_owner_id)
    end

    def current_identity
      return unless current_user_account
      @current_identity ||= current_user_account.identity
    end
  end
end
```

Failure renders the engine's JSON:API error vocabulary (401 invalid token, 403
insufficient scope) via the doorkeeper render-options hooks — one error shape for
the whole engine.

### GraphQL engine (`apis/graph`)

The controller authenticates and hands the schema a context hash:

```ruby
context: { current_identity: current_identity, current_user_account: current_user_account }
```

Endpoints pull the actor from context declaratively — the mutation/resolver
declares `user_story_arg :current_identity` and the engine-local user story
declares `required :current_identity` ([[authoring-graphql-mutations]]).


## Authorization as Scoping

The permission model is **reach, not flags**: an identity may touch what its scoped
queries can reach.

- Every lookup in a user story is scoped to `current_identity`
  (`Queries::ProfilesQuery.new(identity: current_identity).find_by_uuid(uuid)`) —
  an off-limits record is simply not found (the not-found path, no 403 oracle
  leaking existence).
- Collections come from identity-scoped query objects; nothing enumerates outside
  the actor's reach.
- Role/permission *rules* beyond reach (may this identity invite? approve?) are
  domain behaviour: they live in use cases or the owning context's boundary, never
  in controllers, types, or serializers.
- uuids at the edges: external identifiers only; numeric ids never cross.


## Request-Spec Posture

Every endpoint spec states its security posture (the shared examples in
[[testing-rails-requests]]'s shared infrastructure): an-authenticated-route /
a-public-route, with real tokens via the auth helpers. GraphQL acceptance specs
exercise context the same way ([[testing-graphql]]).


## Avoid

- `current_user` vocabulary.
- Authorization checks in controllers, GraphQL types, or serializers — scope in the
  user story, rule in the domain.
- Unscoped finds by uuid (a uuid is an identifier, not a capability).
- Per-endpoint bespoke auth wiring — the engine concern / context hash is the one
  door.
