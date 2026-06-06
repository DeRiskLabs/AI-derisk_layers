---
name: authoring-components
title: Authoring Components
description: How to create and structure a component - a bounded context packaged as an unbuilt gem under components/, with a root-constant public interface and a boot-filled repository registry. Use when creating a component, deciding between component, engine, and api, or wiring a component into the container application.
category: architecture
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - new component
  - bounded context
  - extract a bounded context
  - unbuilt gem
  - component vs engine
  - repository registry
anti_triggers:
  - API or feature engine (needs Rails abstractions)
  - a single layer object inside the app
  - models or migrations
user_invocable: true
last_reviewed_at: 2026-06-06
---


# Authoring Components

A component is a **bounded context packaged as an unbuilt gem** under
`components/<name>/`, consumed by the container application through a Gemfile `path`
entry. It holds pure domain logic: no Rails abstractions, no models, no knowledge of
who calls it. Everything crosses its boundary as messages — in through class methods
on its root constant, out through listener callbacks.


## Required Reading

```text
common_agent_skills/derisk_layers/rails-app-architecture/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-skeleton.md   # every generated file, annotated
references/checklist.md            # authoring checklist
```


## Components, Engines, APIs

Three peer homes for a bounded slice, each a directory of unbuilt gems consumed
through a Gemfile `path` block:

| The slice is… | Home | Skill |
| --- | --- | --- |
| Pure domain logic behind a strict boundary | `components/<name>/` | this skill |
| A feature needing Rails abstractions (views, jobs, mailers, …) | `engines/<name>/` | [[authoring-engines]] |
| A delivery boundary: a collection of API endpoints (REST or GraphQL) | `apis/<name>/` | [[authoring-engines]], then [[authoring-controllers]] / [[authoring-graphql]] |

Engines and apis are the special-case bounded contexts — the ones that need Rails.
**If it needs Rails abstractions, it is an engine; if that engine is a collection of
API endpoints, it lives under `apis/`.** A component holds what is left when those are
stripped away: the domain rules of one bounded context.

The container application's Gemfile consumes all three families the same way:

```ruby
path 'apis' do
  gem 'graph'
  gem 'v1'
end

path 'engines' do
  gem 'mailroom'
end

path 'components' do
  gem 'billing'
end
```

Whatever the home, the container app owns all ActiveRecord models. `lib/` is not a
home for bounded slices: it is reserved for generic libraries that could conceivably
be extracted from the application entirely.


## Creating One

```bash
bin/rails generate layers:component billing
```

generates the component skeleton (every file annotated in
`references/annotated-skeleton.md`):

```text
components/billing/
├── billing.gemspec              # unbuilt gem; depends on layers
├── Gemfile                      # own bundle for the isolated suite
├── .rubocop.yml                 # inherits the application's config
├── README.md                    # the component's contract, stated at its door
├── lib/
│   ├── billing.rb               # root constant: requires, configure/configuration
│   └── billing/
│       ├── version.rb
│       ├── configuration.rb     # carries repo + registration delegators
│       └── repository_registry.rb
└── spec/
    ├── spec_helper.rb           # requires the component only — no Rails
    └── billing_spec.rb
```

It also creates `bin/test_components` (with the first component). Add the gem to the
Gemfile's `path 'components'` block; `components/` sits outside the autoload paths, so
no autoloader configuration is involved.

There is no autoloading inside the component either: every new file is required
explicitly from `lib/billing.rb` (or from a file it requires).


## The Public Interface

The component's public interface is **class methods on the root constant**, each
wrapping a use case:

```ruby
module Billing
  def self.charge_customer(*args, **opts)
    Billing::UseCases::ChargeCustomer.call(*args, **opts)
  end
end
```

- Use cases are the ports of entry to the bounded context; the root-constant methods
  are thin pass-throughs to them.
- Callers — the container, engines, other components — send only these messages.
  Nothing else in the component is public API.
- Outcomes travel back through the listener the caller passed in (`success`/`failure`
  callbacks), never as interrogated return values.
- If the public methods become too many: (a) the context is probably doing too much,
  or (b) group them into collections (modules) mixed into the root constant.

Inside, layer objects follow the usual authoring skills ([[authoring-use-cases]],
[[authoring-query-objects]]), namespaced under the root constant
(`Billing::UseCases::ChargeCustomer` at `lib/billing/use_cases/charge_customer.rb`
within the component) and inheriting a component-local base
(`Billing::BaseUseCase < Layers::BaseLayer`).


## Configuration House Style

The scaffolded `Configuration` is the house pattern for every setting a component
grows:

```ruby
module Billing
  class Configuration
    attr_writer :repo

    delegate :register_repository, :register_repositories, to: :repo

    def repo
      @repo ||= RepositoryRegistry.new
    end
  end
end
```

- A setting with a default is `attr_writer` plus a memoized reader carrying that
  default (`@repo ||= RepositoryRegistry.new`) — the writer is the override seam, the
  reader owns the default.
- `attr_accessor` only for genuinely nil-default flags.
- Logic that picks a default by inspecting the environment lives in a private
  `detect_*` method called from the reader.
- The root constant carries the access pair: a memoized `configuration` and a
  `configure` that yields it.


## Persistence: The Repository Registry

The container owns all models. The component declares how it will address them — its
`RepositoryRegistry` plus the `Configuration` carrying it — and the container fills the
registry at boot through the component's configure block:

```ruby
# config/initializers/components.rb (container application)
Billing.configure do |config|
  config.register_repository invoice: 'Invoice'
  config.register_repositories customer: 'Customer', payment: 'Payment'
end
```

Component code resolves through the configuration and never names host constants:

```ruby
Billing.configuration.repo[:invoice]   # => Invoice (an AR class in the container)
```

Rules:

- `register` takes one pair or many; `register_repository` / `register_repositories`
  are the same method wearing domain names.
- Entries are strings (class names), coerced at registration. Resolution constantizes
  on every access — nothing is memoized — so reloaded host classes are always current
  and boot order never matters. Never cache a resolved constant in the component.
- Registered repositories only have to duck-type to what the component sends them —
  usually a slice of the AR class API. The component defines the protocol; the
  container decides what satisfies it.
- An unknown name raises `Layers::BaseRegistry::NotRegistered`; an entry that does not
  constantize raises `Layers::BaseRegistry::InvalidEntry`.
- There is no class-level registry access (`RepositoryRegistry[:invoice]`): the
  component's memoized configuration is the single access point.


## Dependency Rules

These rules bind components — engines and apis depend on Rails by definition and
follow [[authoring-engines]]:

- The gemspec depends on `layers` (plus any pure-Ruby gems the domain needs) — never
  on `rails`.
- Never name container or engine constants in component code — host classes arrive
  through the registry only.
- One component talks to another only through the other's root-constant public
  interface, passing itself (or a delegate) as listener.
- A use case never calls a user story: user stories belong to delivery boundaries
  (the app, engines, apis), and a component has none.


## Testing

Each component carries its own isolated suite: its own Gemfile and a spec_helper that
requires just the component — no Rails, no container app.

- All components from the app root: `bin/test_components` (each suite under its own
  bundle).
- One component: `BUNDLE_GEMFILE=Gemfile bundle exec rspec` from the component
  directory. While `layers` is unreleased, wire its private source into the
  component's Gemfile first.
- Swap the whole registry rather than registering doubles — the component only ever
  sends `[]`, so anything answering it serves:

```ruby
Billing.configuration.repo = { invoice: fake_invoices }
```

Use cases inside the component are tested with [[testing-use-cases]]; the suite runs
without a database, so the swapped-in fakes stand in for repositories.


## Avoid

- Rails abstractions, `require 'rails'`, or AR models anywhere in the component.
- Putting a bounded slice in `lib/` — components live in `components/`; `lib/` is for
  extractable generic libraries.
- Naming a host constant directly when the registry should carry it.
- Memoizing or caching constants resolved from the registry.
- Reaching into another component's internals (`Other::UseCases::...`) instead of its
  public interface.
- Adding `components/` to autoload or eager-load paths — components are Gemfile-path
  consumed, explicitly required.
