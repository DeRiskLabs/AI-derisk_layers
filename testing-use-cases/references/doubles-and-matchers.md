# common_agent_skills/derisk_layers/testing-use-cases/references/doubles-and-matchers.md


# Doubles and Matchers — Use Cases and User Stories

How to double collaborators and assert message passing in `Layers::BaseLayer` specs.


## Choosing a double

| Need | Use |
| --- | --- |
| A collaborator you only send messages to and assert on | `instance_spy('ClassName')` |
| A collaborator you must stub return values on | `instance_double('ClassName', method: value)` |
| A class-level collaborator (`.new`, class methods) | `class_double('ClassName')` |
| A bare stand-in with no class contract | `double('label')` |

String class names (`instance_double('Account')`) are fine (disable
`RSpec/VerifiedDoubleReference` if RuboCop complains). Prefer giving the double only the
methods the object under test actually calls.

## The listener is always a spy

```ruby
let(:listener) { instance_spy('Listener') }
```

A spy records calls without needing each message stubbed up front, so success/failure
assertions read naturally after the action has run in `execute`.

## Asserting the callback

```ruby
expect(listener).to have_received(on_success_callback).with(account: account)
expect(listener).to have_received(on_failure_callback).with(form: form)
```

- Use the callback **let** (`on_success_callback`), not a literal symbol.
- Always assert `.with(...)` — the keyword payload is part of the contract.

## Stubbing a collaborator class

When the object under test constructs and calls another object, stub the constructor and
assert the message on the returned spy:

```ruby
let(:create_owner) { instance_spy(UseCases::Accounts::CreateOwner) }

before do
  allow(UseCases::Accounts::CreateOwner).to receive(:new)
    .with(identity: identity).and_return(create_owner)
  allow(create_owner).to receive(:call)
end

it 'creates an owner' do
  expect(create_owner).to have_received(:call)
end
```

## Asserting something did NOT happen

```ruby
it 'does not create a guest' do
  expect(create_guest).not_to have_received(:call)
end
```

## Simulating a persistence failure

```ruby
before do
  allow(account).to receive(:close!).and_raise(ActiveRecord::RecordInvalid.new(account))
end
```

## Forbidden

- `listener.on_failure.first_args[:errors]` — `first_args` is **not a real API** (not in
  RSpec or `always_execute`). To inspect failure payloads either:
  - assert `have_received(on_failure_callback).with(errors: expected)`, or
  - (integration style) read the record the object mutated: `account.errors.full_messages`.
- stubbing the object under test (`allow(use_case).to receive(...)`).
- putting `allow(...)` inside an `it`.
