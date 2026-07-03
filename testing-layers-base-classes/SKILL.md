---
name: testing-layers-base-classes
title: Testing Layers Base Classes
description: How to spec an app base class you define over a Layers base (BaseUseCase, BaseUserStory, ApplicationQuery, an app GraphQL endpoint base) - pin only what your base class ADDS, and assert its endowment behaviourally, never structurally. The gem tests its own bases. Use when writing or reviewing an app base-class spec.
category: testing
status: active
version: 2.0
applies_to:
  - Ruby
  - RSpec
  - Layers
priority: REQUIRED
triggers:
  - app base class spec
  - BaseUseCase spec
  - BaseUserStory spec
  - ApplicationQuery spec
  - app GraphQL endpoint base spec
anti_triggers:
  - concrete use case spec
  - concrete user story spec
  - query object spec
  - model spec
  - request spec
  - Layers::BaseLayer spec
  - layers DSL mixin spec
user_invocable: true
last_reviewed_at: "2026-07-03"
---


# Testing Layers Base Classes

Use this skill when your app defines a base class over a Layers base — `BaseUseCase`,
`BaseUserStory`, `ApplicationQuery`, `UserStories::Graph::Base`, an app GraphQL endpoint
base — and you need to spec it.

**The gem tests its own bases.** `Layers::BaseLayer`, the DSL mixins, and
`Layers::Graphql::BaseEndpoint` are already tested exhaustively in the layers gem's own
suite. Your app base-class spec pins **only what your base class adds** — nothing that the
gem already guarantees.

> Editing the vendored layers gem itself (its own base classes, DSL mixins, or specs)?
> That is gem-maintainer work with a different technique — constructor drilling,
> `included_modules` composition pins, host-constant stubbing. See the `layers_dev`
> testing skill for gem internals; it is installed only when layers is vendored for editing.


## Required Reading

```text
[[testing-base-classes]]
[[ruby-testing]]
[[always-execute-rspec]]
```

The general skill defines the mechanics (anonymous includers, behavioural endowment
assertions). This skill maps them onto an app base class over a Layers base.

Supporting reference:

```text
references/checklist.md   # app base-class review checklist
```


## Pin Only What Your Base Class Adds

An app base class spec pins the app's own promises, nothing more:

```ruby
RSpec.describe BaseUseCase do
  it { expect(described_class.ancestors).to include(Layers::BaseLayer) }

  it 'overrides the failure callback default' do
    expect(described_class.on_failure_default).to eq(:use_case_failed)
  end
end
```

Pin: inheritance (`ancestors` includes the Layers base), callback-default overrides your
base sets, extra modules your base includes, and any convenience method your base defines.

Do NOT re-test inputs validation, the null listener, callback-defaults mechanics, or
observer notification through an app base class — that is the gem's contract, already
pinned in the gem.


## Assert Endowment Behaviourally, Not Structurally

When your base class *is* meant to carry a capability (because it inherits from a Layers
base), assert the capability **behaviourally** — that the behaviour is present — not
structurally via `included_modules`. Structural pins couple your spec to which module
supplies the behaviour and to the gem's internal wiring (S-AI-027); a behavioural
assertion survives the gem re-homing a mixin:

```ruby
it { is_expected.to respond_to(:on_success) }          # callback endowment

it 'raises on missing required inputs' do              # inputs endowment
  expect { described_class.new(listener: listener) }.to raise_error(Layers::DSL::MissingRequiredInputs)
end
```

`respond_to` and a missing-input `raise_error` prove the endowment is there without pinning
the gem's internals. Reach for these only when your base's own value depends on the
endowment being present; if the gem already guarantees it and your base adds nothing, you
do not need to assert it at all.


## App GraphQL Endpoint Base Classes

App GraphQL code is tested acceptance-only — see [[testing-graphql]]. The gem tests
`Layers::Graphql::BaseEndpoint` in its own suite. Only an app-defined endpoint *base class*
gets a spec here, and it pins app additions only (its includes, shared arguments), per the
same pin-only-what-you-add rule.
