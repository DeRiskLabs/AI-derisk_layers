---
name: authoring-components
title: Authoring Components
description: How to create and structure a component - a bounded context packaged as an unbuilt gem under components/, with a root-constant public interface and a boot-filled repository registry. Use when creating a component, deciding between component, engine, and api, or wiring a component into the container application.
category: architecture
status: active
version: 1.3
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
last_reviewed_at: 2026-06-10
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

- The interface splits into **commands and queries** (see
  [[cross-context-communication]]). Commands change state: use cases are their ports
  of entry, the root-constant methods thin pass-throughs, outcomes travelling back
  through the listener (`success`/`failure` callbacks) — a command's return value is
  never used. Queries are side-effect-free asks returning the answer itself: an
  enumerable (possibly empty, never nil) for collection questions, the object or nil
  for singular ones.
- Callers — the container, engines, other components — send only these messages.
  Nothing else in the component is public API.
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
- Consumers are clients: a consumer needing different behaviour from this component
  requests a boundary change from its owner (even when that is the same person) —
  the public interface grows, tested on the component's side. No consumer tests or
  reaches into the component's internals.


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

**Root spec vs configuration spec.** The root `billing_spec.rb` pins the component's
**public interface** — the root-constant methods — and nothing about plumbing. The
`Configuration`'s registry defaulting and delegation get their own
`configuration_spec.rb`. Test only what the `Configuration` adds — that `#repo`
**defaults** to the component's `RepositoryRegistry`, and that `register_repository(s)`
**delegates** to it — and **never re-test `Layers::BaseRegistry`** (registration,
constantize-per-access): the `layers` gem owns those tests. This is [[ruby-testing]]'s
"Complete, Fast, Ours" applied to a slice — test the wiring you own, double the gem
you don't:

```ruby
RSpec.describe Billing::Configuration do
  subject(:configuration) { Billing.configuration }

  describe '#repo' do
    it { is_expected.to respond_to(:repo) }
    it { is_expected.to respond_to(:repo=) }

    context 'when no repository registry is injected' do
      it 'defaults to the component RepositoryRegistry' do
        expect(configuration.repo).to be_a(Billing::RepositoryRegistry)
      end
    end
  end

  context 'with an injected repository registry' do
    # Do not re-test Layers::BaseRegistry here — the gem owns that.
    let(:repo) do
      instance_double(
        Billing::RepositoryRegistry,
        register_repository: nil,
        register_repositories: nil
      )
    end

    before { Billing.configure { |c| c.repo = repo } }

    describe '#register_repository' do
      let(:entry) { { invoice: 'Invoice' } }

      execute { configuration.register_repository(**entry) }

      it 'delegates to the repository registry' do
        expect(repo).to have_received(:register_repository).with(**entry)
      end
    end

    describe '#register_repositories' do
      let(:entries) { { customer: 'Customer', payment: 'Payment' } }

      execute { configuration.register_repositories(**entries) }

      it 'delegates to the repository registry' do
        expect(repo).to have_received(:register_repositories).with(**entries)
      end
    end
  end
end
```


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
