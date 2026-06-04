---
name: authoring-use-cases
title: Authoring Use Cases
description: How to write a use-case object - a Layers::BaseLayer subclass that performs one transactional unit of work and reports via success/failure. Use when adding or changing classes under app/lib/use_cases.
category: architecture
status: active
version: 1.1
applies_to:
  - Ruby
  - Rails
  - Layers::BaseLayer
priority: REQUIRED
triggers:
  - write a use case
  - new use case object
  - UseCases class
  - extract service object
anti_triggers:
  - user story (orchestration)
  - query object
  - form object
user_invocable: true
last_reviewed_at: 2026-06-03
---


# common_agent_skills/derisk_layers/authoring-use-cases/SKILL.md

# Authoring Use Cases

A use case is a `Layers::BaseLayer` subclass that performs **one transactional unit of
domain work** (create/update/delete) and reports the outcome by message passing. It does not
know its caller; it calls back a listener.


## Required Reading

```text
common_agent_skills/derisk_layers/layered-architecture-placement/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # a full use case, annotated
references/checklist.md           # authoring checklist
```

Test it with [[testing-use-cases]].


## Placement and Naming

```text
app/lib/use_cases/<domain>/<action>.rb   →  module UseCases::<Domain>; class <Action>
```

A thin base, `ApplicationUseCase < Layers::BaseLayer`, sits at
`app/lib/use_cases/application_use_case.rb`. In engines/APIs, use the engine-local base
(e.g. `<Engine>::BaseUseCase < Layers::BaseLayer`).


## Anatomy

1. Inherit from `ApplicationUseCase`.
2. Declare inputs with `required` / `optional`. Prefer taking a validated **form** object
   (`required :form`) rather than loose attributes.
3. `delegate` the bits of the form you need (`delegate :valid?, :record, to: :form`).
4. Implement `#call`:
   - guard on validity first: `return failure(form: form) unless valid?`
   - wrap writes in `ActiveRecord::Base.transaction`
   - on success: `success(<record>: record)`
   - rescue persistence errors → `failure(form: form)`

```ruby
module UseCases
  module Profiles
    class Update < ApplicationUseCase
      required :form

      delegate :valid?, to: :form
      delegate :profile, to: :form

      def call
        return failure(form: form) unless valid?

        ActiveRecord::Base.transaction do
          profile.update!(first_name: form.first_name, last_name: form.last_name)
        end
        success(profile: profile)
      rescue ActiveRecord::RecordInvalid
        failure(form: form)
      end
    end
  end
end
```


## Rules

- One use case = one action. If you reach for "and", split it (and compose from a user story).
- Report **only** through `success(...)` / `failure(...)`; never return ad-hoc values or
  raise out of `#call` for expected failures.
- Keep keyword payloads stable and meaningful (`success(account:)`, `failure(form:)`) — they
  are the contract the listener depends on.
- Side effects (emails, jobs) belong on observers or are triggered by the caller, not buried
  in `#call`. Keep the use case focused on its transactional work.
- No knowledge of HTTP, GraphQL, or the controller. Those live above the use case.


## Avoid

- accepting loose attributes when a form would validate them — push validation into a form.
- doing reads/queries a query object should own (see [[authoring-query-objects]]).
- multiple responsibilities; orchestration across several use cases belongs in a user story
  ([[authoring-user-stories]]).
