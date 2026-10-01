---
name: authoring-components
title: Authoring Components
description: How to create and structure a component - a bounded context packaged as an unbuilt gem under components/, with a root-constant public interface and a boot-filled repository registry. Use when creating a component, deciding between component, engine, and api, or wiring a component into the container application.
category: authoring
status: active
version: 1.6
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
last_reviewed_at: "2026-10-01"
---


# Authoring Components

A component is a **bounded context packaged as an unbuilt gem** under
`components/<name>/`, consumed by the container application through a Gemfile `path`
entry. It holds pure domain logic: no Rails abstractions, no models, no knowledge of
who calls it. Everything crosses its boundary as messages — in through class methods
on its root constant, out through listener callbacks.


## Required Reading

```text
[[rails-app-architecture]]
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


## Ownership Before Creation

Before generating a component or adding domain constants to an existing one, write the
smallest useful ownership map:

```text
operation / value         owning component       caller
package loading           Definition             container
Object Type / Property    Ontology               Definition
```

Then compare it with the Story's non-goals. Do not create a local substitute for a value
owned by a neighbouring component, and do not implement a future component merely
because the current fixture contains its data. Design and test the neighbour's root
protocol before moving owned behaviour across the boundary.

Repeated domain prefixes in one component (`ObjectTypeBuilder`, `ObjectTypeValidator`,
`ObjectTypeRepository`) are a prompt to check ownership. They may indicate a useful
internal namespace, but they may instead reveal a missing bounded context. Decide which
before reorganizing files.


## Creating One

```bash
bin/rails generate layers:component billing
```

generates the component skeleton (every file annotated in
`references/annotated-skeleton.md`):

```text
components/billing/
├── billing.gemspec              # unbuilt gem; depends on layers
├── Gemfile                      # private layers source + isolated test bundle
├── .rspec                       # loads the component-named spec helper
├── .rubocop.yml                 # inherits the application's config
├── README.md                    # the component's contract, stated at its door
├── lib/
│   ├── billing.rb               # component-owned loader + public root constant
│   └── billing/
│       ├── version.rb
│       ├── configuration.rb     # root config methods + configuration object
│       └── repository_registry.rb
└── spec/
    ├── billing_spec_helper.rb   # activates its bundle, then requires the component
    ├── billing_spec.rb          # pins the root-constant public interface
    └── billing/
        └── configuration_spec.rb
```

It creates the aggregate `bin/test_suite` when that runner is absent. Add the gem to the
Gemfile's `path 'components'` block. `components/` stays outside the Rails autoload and
eager-load paths; each component owns a Zeitwerk loader for its conventional `lib/` tree.
Do not add component paths to the container's Rails loaders.

The root file explicitly requires `configuration.rb` after defining the root module,
because that boundary publishes the root-level `configure` and `configuration` methods.
Zeitwerk loads conventional internal constants such as `RepositoryRegistry`, `VERSION`,
and future layer objects when referenced.


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
  [[cross-context-communication]]). Commands are fallible operations with named
  outcomes—usually state changes, plus the narrow fallible in-memory case described by
  that skill. Root-constant methods are the public protocol, use cases do the work
  behind them, and outcomes travel back through listener (`success`/`failure`) callbacks;
  a command's return value is never used. Queries are side-effect-free asks with no
  domain-failure outcome, returning the answer itself: an
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
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end

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
- `lib/<name>/configuration.rb` carries the root constant's access pair: a memoized
  `configuration` and a `configure` that yields it. Keep these methods with the
  configuration object rather than defining them in `lib/<name>.rb`.


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

- The gemspec depends on `layers` and `zeitwerk` (plus any pure-Ruby gems the domain
  needs) — never on `rails`.
- The isolated Gemfile pins Active Model and Active Support exactly to the generating
  container application's Rails version. This prevents the standalone suite from
  exercising a different framework line from the host application.
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

Each component carries its own isolated suite: its own Gemfile with the private
`layers` source, RSpec, and `always_execute`, plus a component-named spec helper
(`<name>_spec_helper.rb`) that requires `bundler/setup` before `always_execute` and the
component. This keeps direct `rspec` execution inside the component on its isolated
bundle without loading Rails or the container app.

- The complete container and slice suite: `bin/test_suite`.
- One component: `rspec` from the component directory. `bundler/setup` activates the
  local Gemfile; `BUNDLE_GEMFILE=Gemfile bundle exec rspec` remains the explicit form
  used by aggregate runners. The generator wires the unreleased private `layers` source
  into the component Gemfile.
- Swap the whole registry rather than registering doubles — the component only ever
  sends `[]`, so anything answering it serves:

```ruby
Billing.configuration.repo = { invoice: fake_invoices }
```

Use cases inside the component are tested with [[testing-use-cases]]; the suite runs
without a database, so the swapped-in fakes stand in for repositories.

**Root spec vs configuration spec.** The root `billing_spec.rb` pins the component's
**public interface** and its boot contract: root-constant methods and representative
internal constant autoloading. The `Configuration`'s registry defaulting and delegation
get their own `configuration_spec.rb`. Test only what the `Configuration` adds — that `#repo`
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
  consumed and own their Zeitwerk loaders.
