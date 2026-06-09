# Annotated Example — Use Case

Neutral domain: `UseCases::Profiles::Update` — update a profile from inputs, reaching
for a form peer to validate and construct. The companion spec is the annotated example in
[[testing-use-cases]].

```ruby
# frozen_string_literal: true

module UseCases
  module Profiles
    class Update < ApplicationUseCase   # ApplicationUseCase < Layers::BaseLayer
      # Inputs, not a pre-built form: nothing upstream builds one (ruling 16).
      required :profile_id
      optional :first_name, :last_name, :phone

      # Validity is the form peer's job; talk to it through a tiny interface.
      delegate :valid?, to: :form

      def call
        # 1. Guard: invalid input fails fast, handing the form back to the caller.
        return failure(form: form) unless valid?

        # 2. Transactional write: all-or-nothing.
        ActiveRecord::Base.transaction { form.profile.save! }

        # 3. Success message with a meaningful, named payload.
        success(profile: form.profile)

      # 4. Expected persistence failure → failure message (not an exception out of #call).
      rescue ActiveRecord::RecordInvalid
        failure(form: form)
      end


      private

      # The form is a container peer (app/lib/forms ↔ app/lib/use_cases, same level).
      # It validates the inputs and builds the profile this use case persists.
      def form
        @form ||= Forms::Profiles::UpdateForm.new(
          profile_id: profile_id,
          first_name: first_name,
          last_name: last_name,
          phone: phone,
        )
      end
    end
  end
end
```

## Why these choices

- **Inputs, form peer built internally.** A user story (the caller from an engine)
  passes inputs and never builds a form; engine delivery code cannot name a container
  form anyway (ruling 16). The use case reaches for its `Forms::` peer itself. Validation,
  coercion, and construction live in the form ([[authoring-form-objects]]); the use case
  stays about the *write*. A use case that needs no validation skips the form entirely.
- **`delegate :valid?`.** Declaring the one thing the use case asks of the form documents
  the dependency without reaching in.
- **Guard clause first.** The invalid path returns immediately with `failure(form:)`; the
  form responds to `.errors`, so the listener renders without knowing what failed.
- **`transaction` + `save!`.** `save!` raises on failure; the transaction guarantees
  atomicity; the rescue converts the expected failure into a `failure` message.
- **Named payloads.** `success(profile:)` / `failure(form:)` are the contract the listener
  relies on — a named object or an errors-bearing object, never a generic `result`.
