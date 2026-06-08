---
name: authoring-use-cases
title: Authoring Use Cases
description: How to write a use-case object - a Layers::BaseLayer subclass that performs one transactional unit of work and reports via success/failure. Use when adding or changing classes under app/lib/use_cases.
category: architecture
status: active
version: 1.6
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
last_reviewed_at: 2026-06-08
---


# Authoring Use Cases

A use case is a `Layers::BaseLayer` subclass that performs **one transactional unit of
domain work** (create/update/delete) and reports the outcome by message passing. It does not
know its caller; it calls back a listener.

A use case is **the entry point to business logic**: it performs or coordinates the work
inside its bounded context, then calls back to the listener once that work is complete. Its
caller can be a user story, a job, or any other actor in the system.


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

Scaffold the object + spec pair with `bin/rails generate layers:use_case <domain>/<action>`
— never hand-create files a generator scaffolds; fill the generated TODOs.


## Anatomy

1. Inherit from `ApplicationUseCase`.
2. Declare the **raw inputs** the operation needs with `required` / `optional` — not a
   pre-built form. Nothing upstream builds a form for you: a user story (the caller from
   an engine) passes raw inputs, and engine delivery code cannot name a container form
   anyway (ruling 16). The use case is the injected business operation; the form is a
   container **peer** it reaches for.
3. When the operation validates and constructs persistable objects, build a `Forms::`
   peer from the inputs and `delegate :valid?, to: :form`. (A use case that needs no
   validation/construction skips the form entirely — forms are not mandatory.)
4. Implement `#call`:
   - guard on validity first: `return failure(form: form) unless valid?`
   - wrap writes in `ActiveRecord::Base.transaction`
   - on success: `success(<named_object>: ...)`
   - rescue persistence errors → `failure(form: form)` (the form responds to `.errors`)

```ruby
module UseCases
  module Profiles
    class Update < ApplicationUseCase
      required :profile_id
      optional :first_name, :last_name

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
          profile_id: profile_id, first_name: first_name, last_name: last_name,
        )
      end
    end
  end
end
```

`Forms::Profiles::UpdateForm` is a container peer (`app/lib/forms` and `app/lib/use_cases`
sit at the same level and collaborate freely) — see [[authoring-layers-forms]].


## Rules

- One use case = one action. If you reach for "and", split it (and compose from a user story).
- Declarations are per-class: `required`/`optional`, `observer`, and `default_callbacks`
  apply only to the declaring class — nothing inherits. State the complete contract in
  the concrete class; keep base classes behavioural (includes, shared private helpers).
- Report **only** through `success(...)` / `failure(...)`; never return ad-hoc values or
  raise out of `#call` for expected failures.
- Keep keyword payloads stable and meaningful (`success(account:)`, `failure(form:)`) — they
  are the contract the listener depends on.
- A failure payload always carries the means to render errors: an object responding to
  `.errors` (usually the form) or an errors collection itself.
- Side effects (emails, jobs) belong on observers or are triggered by the caller, not buried
  in `#call`. Keep the use case focused on its transactional work.
- No knowledge of HTTP, GraphQL, or the controller. Those live above the use case.
- Never call a user story from a use case. A user story is the boundary of a user
  interaction; a use case sits below it — user interaction boundary → business logic, never
  the reverse.


## Avoid

- validating or coercing inline when a form peer should — push validation into a `Forms::`
  peer the use case builds (do not, however, expect a pre-built form to arrive: ruling 16).
- doing reads/queries a query object should own (see [[authoring-query-objects]]).
- multiple responsibilities; orchestration across several use cases belongs in a user story
  ([[authoring-user-stories]]).
