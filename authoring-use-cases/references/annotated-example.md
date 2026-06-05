# Annotated Example — Use Case

Neutral domain: `UseCases::Profiles::Update` — update a profile from a validated form. The
companion spec is the annotated example in [[testing-use-cases]].

```ruby
# frozen_string_literal: true

module UseCases
  module Profiles
    class Update < ApplicationUseCase   # ApplicationUseCase < Layers::BaseLayer
      # Take a validated form, not loose attributes: validation is the form's job.
      required :form

      # Talk to the form through a tiny, explicit interface.
      delegate :valid?, to: :form
      delegate :profile, to: :form

      def call
        # 1. Guard: invalid input fails fast, handing the form back to the caller.
        return failure(form: form) unless valid?

        # 2. Transactional write: all-or-nothing.
        ActiveRecord::Base.transaction do
          profile.update!(
            first_name: form.first_name,
            last_name: form.last_name,
            phone: form.phone,
          )
        end

        # 3. Success message with a meaningful payload.
        success(profile: profile)

      # 4. Expected persistence failure → failure message (not an exception out of #call).
      rescue ActiveRecord::RecordInvalid
        failure(form: form)
      end
    end
  end
end
```

## Why these choices

- **`required :form`.** Validation, coercion, and "which records does this touch" live in the
  form ([[authoring-form-objects]]); the use case stays about the *write*.
- **`delegate` over reaching in.** Declaring `valid?` and `profile` as delegations documents
  exactly what the use case depends on.
- **Guard clause first.** The invalid path returns immediately with `failure(form:)`; the
  caller already has the form and can render its errors.
- **`transaction` + `update!`.** `update!` raises on failure; the transaction guarantees
  atomicity; the rescue converts the expected failure into a `failure` message.
- **Stable payloads.** `success(profile:)` / `failure(form:)` are the contract the listener
  (controller, resolver, or test) relies on — keep them consistent across the codebase.
