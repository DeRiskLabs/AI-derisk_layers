---
name: rails-app-architecture
title: Rails App Architecture (House Style)
description: The top-level guide to how Ruby/Rails apps are built in this house style - a modular monolith of a main app plus API engines, feature engines, and pure-domain components, with business logic in layer objects (the layers gem). Load first when building or extending a Rails app here; it indexes the specific authoring and testing skills.
category: architecture
status: active
version: 1.5
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - build a rails feature
  - new endpoint
  - where does this go
  - house style
  - app architecture
  - add an engine
  - add a component
anti_triggers:
  - non-Ruby work
user_invocable: true
last_reviewed_at: 2026-06-06
---


# Rails App Architecture (House Style)

The entry-point guide for building Rails apps in this house style. Read this first; it gives
the topology and the request flow, then sends you to the specific skill for the file you are
writing.


## Core Principles

1. **Modular monolith.** A main app plus three families of unbuilt gems, each consumed
   through a Gemfile `path '<location>' do ... end` block: API engines (`apis/*`), feature
   engines (`engines/*`), and components (`components/*`). Engines own their controllers,
   views, jobs, and layer objects, and define their own base classes over the `layers`
   gem. Components are pure-domain bounded contexts behind a root-constant public
   interface — see [[authoring-components]]. The dividing rule: if it needs Rails
   abstractions it is an engine (under `apis/` when it is a collection of API endpoints);
   pure domain logic is a component. The main app owns all ActiveRecord models either
   way; `lib/` is reserved for generic libraries that could be extracted entirely.
2. **Thin framework edges, fat domain objects.** Controllers and GraphQL endpoints only
   translate and render. Behaviour lives in layer objects (use cases, user stories, forms,
   query objects) built on `Layers::BaseLayer` — see [[layered-architecture-placement]].
   The user story is the port between the two: the boundary of a user interaction, out of
   the delivery layer into business logic and back. The use case is the entry point to the
   business logic itself — callable by a user story, a job, or any other actor, and it
   never calls a user story.
3. **Message passing over return values.** Use cases and user stories report outcomes by
   calling back a `listener` (`success`/`failure`), so the same object serves REST, GraphQL,
   and tests unchanged.
4. **Consistent boundaries.** JSON:API responses via serializers; GraphQL via typed
   mutations/resolvers; errors via shared concerns and one error vocabulary; auth via
   concerns/context.
5. **uuids at the edges.** Any record that crosses a public boundary carries a `uuid` as its
   external identifier — in paths, payloads, and lookups; the numeric `id` stays internal
   (and stays the primary key).
6. **Tested in one disciplined style.** RSpec + `always_execute`, one assertion per example —
   see [[ruby-testing]] and the testing skills below.


## Required Reading

```text
common_agent_skills/derisk_layers/layered-architecture-placement/SKILL.md
```

Supporting references in this skill:

```text
references/engine-layout.md   # the modular-monolith topology and how to add an engine
```

The full skill inventory lives in each collection's `INDEX.md`
(`derisk_ruby`, `derisk_rails`, `derisk_layers`).


## Request Flow (one line)

`HTTP / GraphQL → delivery adapter (controller / endpoint, the listener) → user story
(orchestrate) → { form (validate+build), use case (transactional write), query object (reads) }
→ models → serializer / payload`. Full trace: see [[layered-architecture-placement]]
`references/request-flow.md`.


## Where to start, by task

| Building… | Skill |
| --- | --- |
| Deciding which object / where it goes | [[layered-architecture-placement]] |
| A pure-domain bounded context (`components/*`) | [[authoring-components]] |
| An engine — feature slice or API home (`engines/*`, `apis/*`) | [[authoring-engines]] |
| A REST endpoint | [[authoring-controllers]] |
| The GraphQL layer (engine, base classes, types) | [[authoring-graphql]] |
| A GraphQL mutation | [[authoring-graphql-mutations]] |
| A GraphQL query/resolver | [[authoring-graphql-queries]] |
| A user-facing action's orchestration | [[authoring-user-stories]] |
| A single transactional write | [[authoring-use-cases]] |
| Param validation + object building | [[authoring-form-objects]] |
| A scoped read | [[authoring-query-objects]] |
| A model | [[authoring-models]] |
| A JSON:API response | [[authoring-serializers]] |


## The Pairing Rule

Every authoring skill has a testing counterpart — write both, always:

| Code | Spec |
| --- | --- |
| controllers | [[testing-rails-requests]] |
| graphql (all of it) | [[testing-graphql]] (acceptance only) |
| user stories | [[testing-user-stories]] |
| use cases | [[testing-use-cases]] |
| form objects | [[testing-form-objects]] |
| query objects | [[testing-query-objects]] |
| models | [[testing-models]] (+ [[testing-factories]], [[testing-routing]]) |
| base classes / mixins | [[testing-layers-base-classes]] |

All over [[ruby-testing]] + [[always-execute-rspec]] + [[test-driven-development]].
