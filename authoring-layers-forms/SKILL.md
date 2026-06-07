---
name: authoring-layers-forms
title: Authoring Layers Forms
description: The layers overlay on form objects - forms inherit ApplicationForm over Layers::BaseForm, which carries the shared anatomy (form_error_messages + whitelist, model duck typing); each form writes only its accessors, validations, builders, and whitelist override. Use when writing forms in an app using the layers gem.
category: architecture
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - Layers::BaseForm
priority: REQUIRED
triggers:
  - layers form
  - BaseForm
  - ApplicationForm
  - form_error_messages
anti_triggers:
  - non-layers form objects
user_invocable: true
last_reviewed_at: 2026-06-07
---


# Authoring Layers Forms

The general form-object skill is [[authoring-form-objects]] (derisk_rails) — what a
form is, what it validates, what it builds. This overlay covers what changes when the
app uses the layers gem: **the shared anatomy lives in `Layers::BaseForm`**, so a form
never re-implements it.


## Required Reading

```text
common_agent_skills/derisk_rails/authoring-form-objects/SKILL.md
```


## The Base

Apps define one thin base; every form inherits it:

```ruby
class ApplicationForm < Layers::BaseForm
end
```

`Layers::BaseForm` carries:

- `include ActiveModel::Model`
- `form_error_messages` — the curated error reader, filtered through the private
  `report_full_errors_for` whitelist (default: nothing surfaces)
- model duck typing — `new_record?` / `persisted?`, create-style semantics
  (`persisted?` is `false` until the `persisted` writer sets it)


## What Each Form Writes

```ruby
module Forms
  module Orders
    class CreateForm < ApplicationForm
      attr_accessor :customer_name

      validates :customer_name, presence: true


      def order
        @order ||= Order.new(customer_name: customer_name)
      end


      private

      def report_full_errors_for
        %i[customer_name]
      end
    end
  end
end
```

1. `attr_accessor` per input.
2. The validations the form owns (messages via `I18n.t`).
3. Memoized builders for the domain objects the use case will persist.
4. The private `report_full_errors_for` override — the whitelist is each form's
   contract; without it no errors surface through `form_error_messages`.
5. Update-style forms override `persisted?` to return the wrapped record's semantics.

Scaffold with `bin/rails generate layers:form <domain>/<action>` — never hand-create
files a generator scaffolds; fill the generated TODOs. Test with
[[testing-form-objects]]; the duck-typing section is not re-specced per form — the
base is exhaustively specced in the gem.


## Avoid

- re-implementing `form_error_messages`, `new_record?`, or `persisted?` in a form —
  that is the base's job.
- `include ActiveModel::Model` in a form — inherited.
- forgetting the `report_full_errors_for` override — the safe default surfaces
  nothing, so users see no errors.
