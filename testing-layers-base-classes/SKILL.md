---
name: testing-layers-base-classes
title: Testing Layers Base Classes
description: Spec patterns for the Layers::BaseLayer family - composition pins for the DSL mixins, constructor contracts (null listener, callback defaults, inputs validation), success/failure reporting through concrete subclasses, app base classes over the gem, and Graphql::BaseEndpoint. Use when testing the layers gem's own base classes and mixins, or an app base class built on them.
category: testing
status: active
version: 1.0
applies_to:
  - Ruby
  - RSpec
  - Layers
priority: REQUIRED
triggers:
  - Layers::BaseLayer spec
  - layers DSL mixin spec
  - BaseUseCase spec
  - BaseUserStory spec
  - app base class spec
  - Graphql::BaseEndpoint spec
anti_triggers:
  - concrete use case spec
  - concrete user story spec
  - query object spec
  - model spec
  - request spec
user_invocable: true
last_reviewed_at: 2026-06-04
---


# Testing Layers Base Classes

Use this skill to test the `Layers::BaseLayer` family: the gem's own base classes and DSL
mixins (`Layers::DSL::Inputs`, `Observers`, `CallbackDefaults`, …), and the base classes an
app defines over them (`BaseUseCase`, `BaseUserStory`, `ApplicationQuery`,
`UserStories::Graph::Base`).


## Required Reading

```text
common_agent_skills/derisk_ruby/testing-base-classes/SKILL.md
common_agent_skills/derisk_ruby/ruby-testing/SKILL.md
common_agent_skills/derisk_ruby/always-execute-rspec/SKILL.md
```

The general skill defines the mechanics (anonymous includers, the contract list, the
`allocate` + `execute { send(:initialize) }` constructor pattern). This skill maps them
onto the layers gem.

Supporting references in this skill:

```text
references/annotated-example.md   # full BaseLayer and DSL-module specs, annotated
references/checklist.md           # review checklist
```


## Composition Pins

`Layers::BaseLayer` promises its DSL modules; one one-liner each:

```ruby
it { expect(described_class.included_modules).to include(Layers::DSL::Observers) }
it { expect(described_class.included_modules).to include(Layers::DSL::Inputs) }
it { expect(described_class.included_modules).to include(Layers::DSL::NullListener) }
it { expect(described_class.included_modules).to include(Layers::DSL::CallbackDefaults) }
it { expect(described_class.included_modules).to include(Layers::DSL::ClassCallable) }
```

Assert the real module names — the file `callback_defaults.rb` defines `CallbackDefaults`,
not `DefaultCallbacks`.


## Constructor Contracts

Initialization IS the contract for the layers base classes. Per the general pattern,
allocate in `subject` and drive `#initialize` through `execute`, one overridden input per
context. The layers-specific contracts to pin:

- **Null listener**: no listener given → `expect(layer.listener).to be_a(Naught::BasicObject)`
- **Custom listener**: identity with `be`, never `eq`
- **Callback defaults**: `layer.on_success` equals `layer.on_success_default`; custom
  callbacks win when passed
- **Inputs validation**: missing required inputs raise `Layers::DSL::MissingRequiredInputs`;
  undeclared inputs raise `Layers::DSL::UnexpectedInputs` (block-expectation form)


## Reporting Behaviour

`success`/`failure` are private; exercise them through a concrete subclass with a real
`#call`. Assert the listener message with `have_received` on a spy, and observer
notification behaviourally with a callable observer recording into a local — never
`expect(layer).to receive(:notify_observers)` (a message to self):

```ruby
subject(:layer) { success_class.new(listener: listener) }

let(:listener) { spy('Listener') }
let(:notifications) { [] }

let(:success_class) do
  recorder = notifications
  Class.new(described_class) do
    observer -> { recorder << :success }, of_event: :success

    def call
      success(result: true)
    end
  end
end

execute do
  layer.call
end

it 'notifies success observers' do
  expect(notifications).to include(:success)
end

it 'calls the success callback on the listener' do
  expect(listener).to have_received(:on_success).with(result: true)
end
```


## App Base Classes: Pin Only What the App Adds

The gem's suite already tests `Layers::BaseLayer` exhaustively. An app base class spec pins
the app's own promises, nothing more:

```ruby
RSpec.describe BaseUseCase do
  it { expect(described_class.ancestors).to include(Layers::BaseLayer) }

  it 'overrides the failure callback default' do
    expect(described_class.on_failure_default).to eq(:use_case_failed)
  end
end
```

Do not re-test inputs validation, the null listener, or observer mechanics through an app
base class — that is the gem's contract, already pinned in the gem.


## Global Configuration Hygiene

`Layers.configuration` is a global singleton (adapters, logger, GraphQL execution error).
Specs that configure it must not leak; reset after every example, ideally once in the spec
helper:

```ruby
config.after do
  Layers.instance_variable_set(:@configuration, nil)
end
```


## Stubbing the Host's Constants

The gem treats host constants as provided, so base-class specs stub them:

- Query-object base specs: `stub_const('ActiveRecord::Relation', interface_class)` —
  verifying doubles fail `is_a?`, so use a real instance of the stubbed class with partial
  doubles when a message must be recorded.
- Endpoint specs: `stub_const('CreateWidget', spy('UserStoryClass'))` for the user story,
  and either `stub_const('GraphQL::ExecutionError', …)` or
  `Layers.configure { |c| c.graphql_execution_error = … }` for the error class.


## Graphql::BaseEndpoint

The gem tests `Layers::Graphql::BaseEndpoint` exhaustively (resolve wiring, user_story_arg
resolution, error wrapping, callback contracts). App GraphQL code is tested
acceptance-only — see [[testing-graphql]]. Only an app-defined endpoint *base class* gets a
spec here, and it pins app additions only (its includes, shared arguments), per the same
pin-only-what-you-add rule.
