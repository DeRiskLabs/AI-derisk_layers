---
name: authoring-engines
title: Authoring Engines
description: How to operationally create a mountable engine - feature engines under engines/, API engines under apis/ - covering generation, namespace stance, mounting, engine-local layer bases, and spec wiring. Use when adding a new engine or bringing one to house shape.
category: architecture
status: active
version: 2.0
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
last_reviewed_at: 2026-06-07
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
bin/rails generate layers:engine invoicing                # feature engine, engines/
bin/rails generate layers:engine v2 --family api          # api engine, apis/
```

Never hand-create the shell — the generator emits the house shape directly
(`references/annotated-anatomy.md` shows the target): gemspec, `engine.rb` in the
family stance, routes skeleton, engine-namespaced `ApplicationController`,
engine-local layer bases, the injected registries (use cases + query objects) with
their `Configuration` and root-constant `configure` block, a container initializer
(`config/initializers/<name>.rb`), a standalone spec home (helpers, schema-less
dummy app, a green root spec), `bin/test_suite` when absent, the container Gemfile
`path` entry, and the mount line. Run `bundle install` after generating (the Gemfile
gained a path gem), then fill the TODOs.

After generating:

1. Add every Rails-facing dependency the engine owns to its gemspec (`sidekiq`,
   `slim-rails`, `jsonapi-serializer`, …).
2. Confirm the container wiring the generator injected:

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


## Injected Registries (doctrine ruling 15)

Engines never touch ActiveRecord directly, and engine code makes **no static
reference to constants the engine does not own** — no container models, no container
use cases or queries, no other slice's internals. Domain behaviour is injected: the
engine declares a **use-case registry** (commands) and a **query-object registry**
(queries), and the container binds them in the engine's initializer:

```ruby
# config/initializers/invoicing.rb (container application)
Invoicing.configure do |config|
  config.register_use_case create_invoice: 'UseCases::Invoices::Create'
  config.register_query_object invoices: 'Queries::InvoicesQuery'
end
```

Engine code resolves through its own configuration:

```ruby
Invoicing.configuration.use_cases[:create_invoice]   # a command — call with a listener
Invoicing.configuration.queries[:invoices]           # a query object class
```

Entries are strings, constantized per access — registering a class that does not
exist yet is safe. The rule is strict because it is load-bearing: one static host
reference breaks the engine's standalone schema-less suite. Engine-owned constants
(`UseCases::Invoicing::*`, `Invoicing::*`) are the engine's to name; engine-local
use cases remain legitimate for Rails-side logic that should not sit in a
controller, under the same no-direct-AR rule. AR interaction happens where AR is
available: the container's own use cases and queries, or components through their
repository registries.


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

**A bounded slice owns its specs and runs them in its own directory.** The engine's
suite is fully standalone: own Gemfile (rspec-rails, always_execute, layers pinned
to the private git source), own helpers, and a **schema-less dummy app** — no
models, no migrations, no database, nothing to drift:

```text
engines/invoicing/
├── .rspec                       # --require rails_helper
└── spec/
    ├── spec_helper.rb           # always_execute + RSpec config
    ├── rails_helper.rb          # boots spec/dummy
    ├── dummy/config/            # application.rb (explicit root), environment, routes
    ├── invoicing_spec.rb        # generated root spec — registries present
    ├── use_cases/invoicing/     # the engine's layer objects
    ├── user_stories/invoicing/
    └── requests/                # the engine's endpoints, against the dummy
```

- Run it from the engine directory: `cd engines/invoicing && bundle exec rspec`.
  A human+agent pair works entirely inside the engine — code and specs, one bounded
  context.
- Specs swap whole registries for fakes (anything answering `[]` serves):
  `Invoicing.configuration.use_cases = { create_invoice: fake_use_case }`. AR is
  mocked at the use-case/query boundary; the AR objects themselves are thoroughly
  tested in the container.
- The dummy app is generated and tiny: `action_controller` railtie, explicit
  `config.root` (without it Rails walks up to the container's `config.ru` and loads
  the container's initializers), session store (feature) or `api_only` (API), and a
  routes file mounting the engine — that is all a request spec needs.
- The full sweep is `bin/test_suite` at the application root: the container suite
  plus every `components/*/`, `engines/*/`, `apis/*/` slice, each run in its own
  directory with its own bundle.
- Real crossings are validated at delivery level in the **container's** suite
  (doctrine ruling 13) — the engine's isolated suite proves the engine against its
  declared contracts; the container's acceptance specs prove the bindings.

Layer objects follow their usual testing skills ([[testing-use-cases]],
[[testing-user-stories]]) with registry fakes in place of factories; delivery
follows [[testing-rails-requests]] (or [[testing-graphql]] for the GraphQL engine)
against the dummy app, with container-level acceptance specs covering the real
wiring.

Cross-context behaviour is never tested by reaching into another context. Boundaries
are hard and tested where they live; a consumer needing different behaviour requests
a boundary change from the context's owner (even when that is the same person), and
the grown boundary is tested on its own side. Crossings are validated at delivery
level: the request/acceptance specs of the interaction's owner.


## Rules

- API engines own their user stories: a graph-facing user story is a boundary of the
  graph API, so it lives in the engine
  (`apis/graph/app/lib/user_stories/graph/...`) — never in the main app.
- Engines reach domain behaviour by sending messages: their own layer objects, the
  injected use-case/query-object registries, or another context's root-constant
  public interface with the caller as listener.
- The container app owns all ActiveRecord models and binds the registries in the
  engine's initializer. Engines never touch AR directly.
- Controllers, jobs, and mailers stay thin: translate, delegate to a user story or
  use case, render the callback outcome.


## Avoid

- Pure domain logic in an engine — strip the Rails abstractions away and it is a
  component ([[authoring-components]]).
- Skipping `isolate_namespace`.
- Engine-local models or migrations.
- Static references to constants the engine does not own (container models, use
  cases, queries) — one breaks the standalone schema-less suite; the registry is
  the seam.
- Schema, factories, or a database in the engine's dummy app — AR is mocked at the
  registry boundary; a dummy that needs schema is drift waiting to happen.
- Testing another context's internals from the engine — request a boundary change
  instead.
- Namespacing layer objects under the engine constant (`Invoicing::UseCases::...`) —
  they belong to the app-wide families (`UseCases::Invoicing::...`).
- Leaving the engine's session middleware in place in a feature engine (duplicate
  cookies).
