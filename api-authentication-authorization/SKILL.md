---
name: api-authentication-authorization
title: API Authentication and Authorization
description: Where auth lives in the API engines - authentication at the engine edge (Doorkeeper concern for REST, context hash for GraphQL) producing a security credential (current_authorization), authorization as credential scoping inside user stories. Use when wiring auth for an endpoint or deciding where a permission check goes.
category: architecture
status: active
version: 1.1
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - authentication
  - authorization
  - current_authorization
  - current_identity
  - protect an endpoint
  - permission check
anti_triggers:
  - identity domain modelling itself
user_invocable: true
last_reviewed_at: 2026-06-07
---


# API Authentication and Authorization

Two different questions, two different homes:

- **Authentication** ("who is this?") happens once, at the API engine's edge, and
  produces a **security credential**.
- **Authorization** ("what may they touch?") is credential scoping inside the layer
  objects — primarily user stories.

`current_authorization` — the security credential — is the actor vocabulary
everywhere (never `current_user`, and never a raw identity travelling on its own;
where an identity or role is needed, the credential answers — doctrine ruling 15).
Authentication will ultimately be its own engine backed by an authorization gem;
until that lands, the engine edge derives the credential as shown below.


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

    def current_authorization
      return unless current_user_account
      @current_authorization ||= current_user_account.identity
    end
  end
end
```

(The credential is the identity for now; when the authentication engine lands, the
same method returns the richer credential object — callers never know the
difference.)

Failure renders the engine's JSON:API error vocabulary (401 invalid token, 403
insufficient scope) via the doorkeeper render-options hooks — one error shape for
the whole engine.

### GraphQL engine (`apis/graph`)

The controller authenticates and hands the schema a context hash:

```ruby
context: { current_authorization: current_authorization, current_user_account: current_user_account }
```

Endpoints pull the actor from context declaratively — the mutation/resolver
declares `user_story_arg :current_authorization` and the engine-local user story
declares `required :current_authorization` ([[authoring-graphql-mutations]]).


## Authorization as Scoping

The permission model is **reach, not flags**: an actor may touch what its scoped
queries can reach.

- Every lookup in a user story is scoped to `current_authorization`
  (`Queries::ProfilesQuery.new(authorization: current_authorization).find_by_uuid(uuid)`)
  — an off-limits record is simply not found (the not-found path, no 403 oracle
  leaking existence).
- Collections come from credential-scoped query objects; nothing enumerates outside
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
