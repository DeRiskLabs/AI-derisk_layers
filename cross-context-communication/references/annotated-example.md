# Annotated Example — One Crossing, Both Sides

A feature engine (`invoicing`) consumes the `accounts` component: one command, one
query. Neutral domain; the shapes are the contract.


## The callee's boundary — components/accounts/lib/accounts.rb

```ruby
# frozen_string_literal: true

require 'layers'
require 'accounts/version'
require 'accounts/repository_registry'
require 'accounts/configuration'
require 'accounts/base_use_case'
require 'accounts/use_cases/register_identity'
require 'accounts/queries/profiles'

module Accounts
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def register_identity(*args, **opts)
      UseCases::RegisterIdentity.call(*args, **opts)
    end

    def profiles_for(identity_uuid:)
      Queries::Profiles.new.for_identity(identity_uuid).all
    end

    def profile(uuid:)
      configuration.repo[:profile].find_by(uuid: uuid)
    end
  end
end
```

- `register_identity` is a **command**: thin pass-through to the use case, the port
  of entry. Its return value is part of no contract.
- `profiles_for` is a collection **query**: returns an enumerable, possibly empty,
  never nil.
- `profile` is a singular query: the object or nil. Whether either wraps a query
  object, a repository lookup, or something else entirely is invisible to callers —
  decomposition is an implementation detail.


## The command's use case — the contract made explicit

```ruby
# frozen_string_literal: true

module Accounts
  module UseCases
    class RegisterIdentity < BaseUseCase
      required :form

      emits success: [:identity], failure: [:form]

      delegate :valid?, to: :form

      def call
        return failure(form: form) unless valid?

        identity = repo.create!(email: form.email)
        success(identity: identity)
      rescue StandardError
        failure(form: form)
      end


      private

      def repo
        Accounts.configuration.repo[:identity]
      end
    end
  end
end
```

`emits` makes the payload keys the enforced contract: emitted payloads must match
exactly, and the wired listener's callbacks are verified at construction — a
mis-wired caller fails in its first constructing test.


## The caller's side — an invoicing user story

```ruby
# frozen_string_literal: true

module UserStories
  module Invoicing
    class OnboardCustomer < BaseUserStory
      required :form

      def call
        Accounts.register_identity(form: form, listener: self)
      end

      def success(identity:)
        listener.success(customer: build_customer(identity))
      end

      def failure(form:)
        listener.failure(form: form)
      end


      private

      def build_customer(identity)
        Customer.new(identity_uuid: identity.uuid)
      end
    end
  end
end
```

- The caller sends the public message with itself as listener and implements exactly
  the callbacks the `emits` declaration names.
- The identity crosses onward as a uuid — never as a constant from inside `Accounts`.
- Reading data is the simpler contract — no listener:

```ruby
Accounts.profiles_for(identity_uuid: current_identity.uuid).map { |p| present(p) }
```


## The caller's spec — stub the boundary, assert the message

```ruby
RSpec.describe UserStories::Invoicing::OnboardCustomer do
  subject(:story) { described_class.new(form: form, listener: listener) }

  let(:form) { instance_double(Forms::Invoicing::Onboarding, valid?: true) }
  let(:listener) { double('listener', success: nil, failure: nil) }

  before { allow(Accounts).to receive(:register_identity) }

  execute { story.call }

  it 'sends the command across the boundary' do
    expect(Accounts).to have_received(:register_identity)
      .with(form: form, listener: story)
  end
end
```

The neighbour's internals never appear: the spec stubs the public interface
(anything answering the message serves) and asserts the outgoing command was sent —
the assertion-target grid's rule for outgoing commands. The callee's behaviour is
tested on its own side, in its own spec directory; the whole crossing is validated
by the interaction owner's delivery-level specs.
