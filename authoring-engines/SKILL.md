---
name: authoring-engines
title: Authoring Engines
description: How to operationally create a mountable engine - feature engines under engines/, API engines under apis/ - covering generation, namespace stance, mounting, engine-local layer bases, and spec wiring. Use when adding a new engine or bringing one to house shape.
category: architecture
status: active
version: 1.1
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - new engine
  - add an engine
  - mountable engine
  - api engine
  - feature engine
  - mount an engine
anti_triggers:
  - pure domain context (component)
  - a single endpoint in an existing engine
user_invocable: true
last_reviewed_at: 2026-06-06
---


# Authoring Engines

An engine is a bounded slice that **needs Rails abstractions**, packaged as a mountable
unbuilt gem and consumed through a Gemfile `path` block. Two families:

- **Feature engines** (`engines/<name>/`) own a feature slice: controllers, views,
  jobs, mailers, and their own layer objects.
- **API engines** (`apis/<name>/`) are delivery boundaries: collections of API
  endpoints (REST or GraphQL) plus protocol concerns — serializers, types, error
  formatting — and **their own user stories**.

If the slice needs no Rails abstractions at all, it is not an engine — it is a
component ([[authoring-components]]).


## Required Reading

```text
common_agent_skills/derisk_layers/rails-app-architecture/SKILL.md
common_agent_skills/derisk_layers/rails-app-architecture/references/engine-layout.md
```

Supporting references in this skill:

```text
references/annotated-anatomy.md   # gemspec, engine.rb stances, routes, root file
references/checklist.md           # authoring checklist
```

For the GraphQL engine's internals (types, base endpoint classes, schema wiring) load
[[authoring-graphql]] — this skill stops at the engine shell.


## Creating One

```bash
bin/rails plugin new engines/invoicing --mountable
```

then bring it to house shape (`references/annotated-anatomy.md` shows the target):

1. Prune the generated dummy-app scaffolding — the container is the dummy app. The
   engine keeps its own `spec/` directory (see Spec Wiring).
2. Tighten the gemspec: the engine declares `rails` and every Rails-facing dependency
   it owns (`sidekiq`, `slim-rails`, `jsonapi-serializer`, …).
3. Set the `engine.rb` stance for the family (feature or API — see below).
4. Consume it from the container's Gemfile `path` block and mount it:

```ruby
path 'engines' do
  gem 'invoicing'
end
```

```ruby
# config/routes.rb (container application)
mount Invoicing::Engine, at: '/'
```

Feature engines mount at `/` and scope their own prefix inside their routes file
(`scope 'invoicing' do ... end`); API engines mount at their protocol path
(`mount V1::Engine, at: '/api', as: :api`).


## Namespace Stance

`isolate_namespace <Name>` — always.

- **Rails-facing classes** live under the engine constant:
  `Invoicing::ProfilesController`, `Invoicing::ApplicationController`, views, helpers,
  jobs, mailers.
- **Layer objects do not.** The engine's `app/lib` is an autoload root, so layer
  objects join the app-wide families with an engine sub-namespace:
  `UseCases::Invoicing::CreateInvoice`, `UserStories::Invoicing::SendStatement`,
  `Forms::Invoicing::Statement`. One vocabulary of `UseCases::*` / `UserStories::*` /
  `Forms::*` across the whole monolith, partitioned by owner.


## Engine-Local Bases

Each engine defines thin bases over the `layers` gem so its objects share defaults:

```ruby
module UserStories
  module Invoicing
    class BaseUserStory < Layers::BaseLayer
    end
  end
end
```

likewise `UseCases::Invoicing::BaseUseCase < Layers::BaseLayer`, and
`Invoicing::ApplicationController` carrying the shared controller concerns. Bases stay
behavioural (includes, shared private helpers): all layer declarations are per-class —
nothing inherits — so concrete classes state their own contracts.


## engine.rb Stances

The full annotated files are in `references/annotated-anatomy.md`.

- **Feature engine** (serves HTML inside the main app's session): generator config
  (rspec, factory_bot, template engine), i18n load path, and the session-middleware
  dedup — delete the engine's own `Cookies`/`Session`/`Flash` middleware and re-use
  the main app's, so users never carry duplicate cookies.
- **API engine**: `config.api_only = true`, null session store, cookie/session/flash
  middleware deleted, JSON as the default render format, forgery protection off.


## Spec Wiring

**A bounded slice owns its specs.** The engine's specs live in the engine, mirroring
its code, and run under the container application's environment — the container is
the dummy app:

```text
engines/invoicing/spec/
├── rails_helper.rb              # one line: require_relative '../../../spec/rails_helper'
├── lib/
│   ├── use_cases/invoicing/     # mirrors app/lib
│   └── user_stories/invoicing/
├── requests/                    # the engine's endpoints
└── features/                    # journeys the engine owns
```

- Scoped run, from the application root: `bundle exec rspec engines/invoicing/spec` —
  green on its own, so a human+agent pair can work entirely inside the engine with
  the whole bounded context (code and specs) in context.
- The full suite includes every slice's specs — wire `engines/*/spec` and
  `apis/*/spec` into the suite's pattern.
- Engine-internal plain-Ruby code (the engine's `lib/`) is tested here too, like
  everything the engine owns.
- No per-engine dummy app and no engine-local bundle for specs: engines depend on the
  container's models by doctrine, so their specs boot the container environment.

Layer objects follow their usual testing skills ([[testing-use-cases]],
[[testing-user-stories]]); delivery follows [[testing-rails-requests]] (or
[[testing-graphql]] for the GraphQL engine).

Cross-context behaviour is never tested by reaching into another context. Boundaries
are hard and tested where they live; a consumer needing different behaviour requests
a boundary change from the context's owner (even when that is the same person), and
the grown boundary is tested on its own side. Crossings are validated at delivery
level: the request/acceptance specs of the interaction's owner.


## Rules

- API engines own their user stories: a graph-facing user story is a boundary of the
  graph API, so it lives in the engine
  (`apis/graph/app/lib/user_stories/graph/...`) — never in the main app.
- Engines reach domain behaviour by sending messages: their own layer objects, or
  another context's root-constant public interface with the caller as listener.
- The container app owns all ActiveRecord models. Engines read and write them through
  layer objects, never through engine-local models.
- Controllers, jobs, and mailers stay thin: translate, delegate to a user story or
  use case, render the callback outcome.


## Avoid

- Pure domain logic in an engine — strip the Rails abstractions away and it is a
  component ([[authoring-components]]).
- Skipping `isolate_namespace`.
- Engine-local models or migrations.
- A per-engine dummy app or an engine-local bundle for specs — specs live in the
  engine but boot the container environment.
- Testing another context's internals from the engine — request a boundary change
  instead.
- Namespacing layer objects under the engine constant (`Invoicing::UseCases::...`) —
  they belong to the app-wide families (`UseCases::Invoicing::...`).
- Leaving the engine's session middleware in place in a feature engine (duplicate
  cookies).
