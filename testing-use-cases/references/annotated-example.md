# Annotated Example — Use Case Spec

Neutral domain: `UseCases::Profiles::Update` — a use case that takes inputs, builds a
form peer to validate and construct, updates the profile in a transaction, and reports via
the listener.


## The Object Under Test

The use case being specced, compact — the fully annotated version is the annotated example
in [[authoring-use-cases]]:

```ruby
# frozen_string_literal: true

module UseCases
  module Profiles
    class Update < ApplicationUseCase
      required :profile_id
      optional :first_name, :last_name, :phone

      delegate :valid?, to: :form

      def call
        return failure(form: form) unless valid?

        ActiveRecord::Base.transaction { form.profile.save! }
        success(profile: form.profile)
      rescue ActiveRecord::RecordInvalid
        failure(form: form)
      end


      private

      def form
        @form ||= Forms::Profiles::UpdateForm.new(
          profile_id: profile_id, first_name: first_name, last_name: last_name, phone: phone,
        )
      end
    end
  end
end
```


## The Spec

```ruby
# frozen_string_literal: true

require 'rails_helper'                       # use cases live in a Rails app; rails_helper boots it

RSpec.describe UseCases::Profiles::Update do
  # Named subject built from **params. Every example shares this construction; contexts
  # change inputs by re-pointing a leaf `let`, never by rebuilding the subject.
  subject(:use_case) { described_class.new(**params) }

  # --- The listener contract -------------------------------------------------
  # The use case reports outcomes by calling back a listener. In a spec the listener is a
  # spy so we can assert which callback fired and with what. The callback NAMES are lets so
  # the spec stays correct if the defaults change.
  let(:listener) { instance_spy('Listener') }
  let(:on_success_callback) { :on_success }
  let(:on_failure_callback) { :on_failure }
  let(:valid_listener_args) do
    { listener: listener, on_failure: on_failure_callback, on_success: on_success_callback }
  end

  # --- The use case's own inputs --------------------------------------------
  # The use case takes RAW inputs and builds its form peer internally. The use case only
  # talks to the form through a small interface (valid?, profile), so we double that
  # interface and stub the construction the use case performs.
  let(:profile) { instance_spy('Profile') }
  let(:form) { instance_double('Forms::Profiles::UpdateForm', valid?: true, profile: profile) }
  let(:valid_use_case_args) do
    { profile_id: 1, first_name: 'Ada', last_name: 'Lovelace', phone: '+1 555-123-4567' }
  end

  before { allow(Forms::Profiles::UpdateForm).to receive(:new).and_return(form) }

  # --- Compose the params, with a single override point ----------------------
  let(:valid_params) { valid_listener_args.merge(valid_use_case_args) }
  let(:params) { valid_params }


  describe '.call' do
    # The action under test runs once before every example (always_execute). Examples below
    # are pure assertions — no setup, no stubbing, no `.call`.
    execute do
      use_case.call
    end

    context 'when successful' do
      it 'persists the profile' do
        expect(profile).to have_received(:save!)
      end

      it 'notifies the listener of success' do
        expect(listener).to have_received(on_success_callback).with(profile: profile)
      end
    end

    context 'when validation fails' do
      # Override exactly one thing: an invalid form. Everything else is inherited.
      let(:form) { instance_double('Forms::Profiles::UpdateForm', valid?: false, profile: profile) }

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback).with(form: form)
      end
    end

    context 'when the save raises' do
      # Stubbing belongs in `before`, never in `it`.
      before do
        allow(profile).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(profile))
      end

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback).with(form: form)
      end
    end
  end
end
```


## Why these choices

- **Spy listener + callback lets.** The object's public contract *is* the message it sends.
  Asserting `have_received(on_success_callback)` tests that contract directly; using the let
  name (not a literal `:on_success`) keeps the spec honest if defaults change.
- **Inputs + stubbed form construction.** The use case takes inputs and builds its
  form peer (ruling 16). The form is the collaborator, so we double its interface and stub
  the `.new` the use case calls — `before { allow(Forms::...).to receive(:new)... }`. A
  DB-backed variant (real form + factory profile) is equally valid for a container use case.
- **`params` layering.** A context overrides a single `let` (e.g. `form`) and leaves the
  rest intact, instead of reconstructing the whole argument hash.
- **`describe '.call'` + `execute`.** The action is declared once; each `it` asserts one
  observable effect of that single run.
- **All three outcomes covered.** Success, invalid form, and persistence failure are the
  use case's whole contract — each gets a context ending in the right callback.
