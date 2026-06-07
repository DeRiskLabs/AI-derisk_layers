---
name: rails-app-architecture
title: Rails App Architecture (House Style)
description: The top-level guide to how Ruby/Rails apps are built in this house style - a modular monolith of a main app plus API engines, feature engines, and pure-domain components, with business logic in layer objects (the layers gem). Load first when building or extending a Rails app here; it indexes the specific authoring and testing skills.
category: architecture
status: active
version: 2.1
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
last_reviewed_at: 2026-06-07
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
   gem; they never touch ActiveRecord directly — domain behaviour is injected through
   use-case and query-object registries the container binds in an initializer
   ([[authoring-engines]]). Components are pure-domain bounded contexts behind a
   root-constant public interface — see [[authoring-components]]. The dividing rule: if
   it needs Rails abstractions it is an engine (under `apis/` when it is a collection of
   API endpoints); pure domain logic is a component. The main app owns all ActiveRecord
   models either way; `lib/` is reserved for generic libraries that could be extracted
   entirely.
2. **Thin framework edges, fat domain objects.** Controllers and GraphQL endpoints only
   translate and render. Behaviour lives in layer objects (use cases, user stories, forms,
   query objects) built on `Layers::BaseLayer` — see [[layered-architecture-placement]].
   The user story is the port between the two: the boundary of a user interaction, out of
   the delivery layer into business logic and back. The use case is the entry point to the
   business logic itself — callable by a user story, a job, or any other actor, and it
   never calls a user story.
3. **Message passing over return values — for commands.** Use cases and user stories
   report outcomes by calling back a `listener` (`success`/`failure`), so the same object
   serves REST, GraphQL, and tests unchanged. Queries are the deliberate exception:
   side-effect-free asks returning the answer itself (collection, or object-or-nil) —
   see [[cross-context-communication]].
4. **Consistent boundaries.** JSON:API responses via serializers; GraphQL via typed
   mutations/resolvers; errors via shared concerns and one error vocabulary; auth via
   concerns/context.
5. **uuids at the edges.** Any record that crosses a public boundary carries a `uuid` as its
   external identifier — in paths, payloads, and lookups; the numeric `id` stays internal
   (and stays the primary key).
6. **Tested in one disciplined style.** RSpec + `always_execute`, one assertion per example —
   see [[ruby-testing]] and the testing skills below. A bounded slice owns its specs and
   runs them standalone in its own directory: components with no Rails at all; engines
   and apis against a schema-less dummy app with their registries swapped for fakes.
   `bin/test_suite` walks the container suite plus every slice; real crossings are
   validated at delivery level in the container suite. Cross-context behaviour is
   tested at the boundary contract, never by reaching into another context.


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


## Decision tree: what to generate

Generators own structure; you fill in semantics. **Never hand-create a file a generator
scaffolds.** Walk the tree to the generator command, then read the paired skill to fill
the TODOs.

```text
What are you building?
│
├─ A whole bounded context with no Rails abstractions (pure domain)?
│     → bin/rails generate layers:component <name>
│       then [[authoring-components]] — root-constant interface, repository registry
│
├─ A bounded slice that needs Rails abstractions (controllers, views, jobs, mailers,
│  GraphQL, serializers)?
│     ├─ a collection of API endpoints?   → layers:engine <name> --family api   (apis/)
│     └─ a feature slice?                 → layers:engine <name>                (engines/)
│       then [[authoring-engines]] — registries injected by the container
│
├─ A delivery endpoint inside an existing engine?
│     ├─ GraphQL mutation (a write)?      → layers:graphql_mutation <domain>/<action>
│     │                                     then [[authoring-graphql-mutations]]
│     ├─ GraphQL query (a read)?          → layers:graphql_query <domain> [--single]
│     │                                     then [[authoring-graphql-queries]]
│     └─ REST/JSON:API endpoint?          → [[authoring-controllers]]
│
├─ A piece of business logic?
│     ├─ orchestrates a whole user action (find → act → respond)?
│     │     → bin/rails generate layers:user_story <domain>/<action>
│     │       then [[authoring-user-stories]]
│     ├─ one transactional write?
│     │     → bin/rails generate layers:use_case <domain>/<action>
│     │       then [[authoring-use-cases]]
│     ├─ validates params and builds domain objects?
│     │     → bin/rails generate layers:form <domain>/<action>
│     │       then [[authoring-layers-forms]] / [[authoring-form-objects]]
│     └─ a scoped, composable read?
│           → bin/rails generate layers:query_object <name>
│             then [[authoring-query-objects]]
│
└─ Rails-specific, no generator yet — read the skill and place by hand:
      model            → [[authoring-models]]
      serializer       → [[authoring-serializers]]
      job              → [[authoring-layers-jobs]] (over [[authoring-jobs]])
      mailer           → [[authoring-mailers]]
      rake task        → [[authoring-rake-tasks]]
      endpoint auth    → [[api-authentication-authorization]]
```

Earlier, design-level questions — **where** a boundary goes or how to split a context —
are [[boundaries-and-context-mapping]]; **which** object a responsibility becomes is
[[layered-architecture-placement]].


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
| jobs | [[testing-jobs]] |
| models | [[testing-models]] (+ [[testing-factories]], [[testing-routing]]) |
| base classes / mixins | [[testing-layers-base-classes]] |

All over [[ruby-testing]] + [[always-execute-rspec]] + [[test-driven-development]].
