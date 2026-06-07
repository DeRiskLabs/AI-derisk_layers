---
name: testing-use-cases
title: Testing Use Cases
description: Spec pattern for testing Layers::BaseLayer use cases (UseCases::*) that communicate by message passing to a listener. User stories share these mechanics - see testing-user-stories. Use when writing or modifying specs for classes under app/lib/use_cases.
category: testing
status: active
version: 1.2
applies_to:
  - Ruby
  - Rails
  - RSpec
  - always_execute
  - Layers::BaseLayer
priority: REQUIRED
triggers:
  - use case spec
  - service object spec
  - BaseLayer spec
  - testing success and failure callbacks
anti_triggers:
  - model spec
  - request spec
  - graphql acceptance spec
user_invocable: true
last_reviewed_at: 2026-06-03
---


# Testing Use Cases

Use this skill when writing specs for `Layers::BaseLayer` use cases (`UseCases::*`).
User stories share these mechanics — [[testing-user-stories]] builds on this skill.


## Required Reading

```text
common_agent_skills/derisk_ruby/ruby-testing/SKILL.md
common_agent_skills/derisk_ruby/always-execute-rspec/SKILL.md
```

Supporting references in this skill (load when writing one of these specs):

```text
references/annotated-example.md     # a full spec, line-by-line, explaining why
references/doubles-and-matchers.md  # instance_spy/double, have_received, stubbing collaborators
references/checklist.md             # pre-merge review checklist
```

Authoring the objects under test: [[authoring-use-cases]].


## What These Objects Do

A `Layers::BaseLayer` does work in `#call` and reports the outcome by message passing:
it calls back a `listener` with a success or failure method and keyword arguments. It does
not return a value you assert on. **Assert on the messages sent to the listener and to
collaborators**, not on return values.


## The Listener Setup

Every use case / user story spec injects a `listener` spy plus the two callback names, and
layers the arguments so individual contexts can override one input at a time.

```ruby
subject(:use_case) { described_class.new(**params) }

let(:listener) { instance_spy('Listener') }
let(:on_success_callback) { :on_success }
let(:on_failure_callback) { :on_failure }

let(:valid_listener_args) do
  {
    listener: listener,
    on_failure: on_failure_callback,
    on_success: on_success_callback,
  }
end

let(:valid_use_case_args) { { form: form } }            # inputs the object declares
let(:valid_params) { valid_listener_args.merge(valid_use_case_args) }
let(:params) { valid_params }                           # contexts re-point :params or a leaf let
```


## The Action Goes in `execute`

Call `#call` inside an `execute` block under `describe '.call'`. It runs once before each
example; examples assert only.

```ruby
describe '.call' do
  execute do
    use_case.call
  end

  # contexts + it blocks here
end
```


## Canonical Contexts

Cover, at minimum, the outcomes the object can produce. Use `context 'when ...'`:

- `context 'when successful'`
- `context 'when validation fails'`
- `context 'when save fails'` (persistence raised)
- plus domain conditions: `when not authorized`, `when the record does not exist`, etc.


## Asserting Outcomes

One expectation per `it`. Assert the listener received the right callback with the right
keyword arguments, and that collaborators received the expected messages.

```ruby
context 'when successful' do
  before { allow(profile).to receive(:update!) }

  it 'updates the profile' do
    expect(profile).to have_received(:update!).with(first_name: first_name)
  end

  it 'notifies the listener of success' do
    expect(listener).to have_received(on_success_callback).with(profile: profile)
  end
end

context 'when validation fails' do
  let(:form) { instance_double('Forms::Profiles::UpdateForm', valid?: false, profile: profile) }

  it 'notifies the listener of failure' do
    expect(listener).to have_received(on_failure_callback).with(form: form)
  end
end
```

Use the callback **let names** (`on_success_callback`) in the expectation, not literal
symbols, so the spec stays correct if the default callback names change.


## Doubles: Mock-Heavy vs Integration

Two valid styles; choose per object:

- **Mock-heavy (pure unit):** double every collaborator with `instance_double` /
  `instance_spy` (string class names are fine). Stub collaborator classes via
  `allow(Collaborator).to receive(:new).with(...).and_return(spy)` and assert
  `have_received(:call)`. No database. Preferred for objects that orchestrate other objects.
- **Integration:** build real records with `FactoryBot.create`, run `#call`, then `reload`
  and assert persisted state. Use when the logic is tightly coupled to ActiveRecord behaviour.

```ruby
# mock-heavy collaborator assertion
before do
  allow(UseCases::Accounts::CreateOwner).to receive(:new)
    .with(identity: identity).and_return(create_owner)
  allow(create_owner).to receive(:call)
end

it 'creates an owner' do
  expect(create_owner).to have_received(:call)
end
```


## Negative and Before/After Assertions

To assert something did **not** happen, assert the spy did not receive the message:

```ruby
it 'does not create a guest' do
  expect(create_guest).not_to have_received(:call)
end
```

For "value did not change" against a real record, use a `change` block matcher (the
delta-assertion exception — the action runs inside the expectation):

```ruby
it 'does not change the name' do
  expect { use_case.call }.not_to change { profile.reload.display_name }
end
```


## Avoid

- `listener.on_failure.first_args[:errors]` — `first_args` is not a real API. Assert
  with `have_received(on_failure_callback).with(errors: ...)` instead.
- multiple expectations in one `it`; setup, stubbing, or the `#call` action inside an `it`.
- stubbing the object under test.


## Preferred Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UseCases::Profiles::Update do
  subject(:use_case) { described_class.new(**params) }

  let(:listener) { instance_spy('Listener') }
  let(:on_success_callback) { :on_success }
  let(:on_failure_callback) { :on_failure }
  let(:valid_listener_args) do
    { listener: listener, on_failure: on_failure_callback, on_success: on_success_callback }
  end

  let(:form) { instance_double('Forms::Profiles::UpdateForm', valid?: true, profile: profile) }
  let(:profile) { instance_spy('Profile') }
  let(:valid_use_case_args) { { form: form } }
  let(:valid_params) { valid_listener_args.merge(valid_use_case_args) }
  let(:params) { valid_params }


  describe '.call' do
    execute do
      use_case.call
    end

    context 'when successful' do
      it 'notifies the listener of success' do
        expect(listener).to have_received(on_success_callback).with(profile: profile)
      end
    end

    context 'when validation fails' do
      let(:form) { instance_double('Forms::Profiles::UpdateForm', valid?: false, profile: profile) }

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback).with(form: form)
      end
    end
  end
end
```
