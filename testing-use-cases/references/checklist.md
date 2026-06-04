# common_agent_skills/derisk_layers/testing-use-cases/references/checklist.md


# Review Checklist — Use Case / User Story Specs

Binary checks for a use-case or user-story spec before merge.

## Structure
- [ ] `# frozen_string_literal: true` and `require 'rails_helper'` at the top.
- [ ] Named `subject` built as `described_class.new(**params)`.
- [ ] `listener` is an `instance_spy`; `on_success_callback`/`on_failure_callback` are lets.
- [ ] Args layered: `valid_listener_args` + `valid_use_case_args` → `valid_params` → `params`.
- [ ] `describe '.call'` wraps the examples.
- [ ] The action is in a single `execute do … end`; it appears nowhere else.

## Examples
- [ ] Exactly one expectation per `it`.
- [ ] No setup, stubbing, or `.call` inside any `it` (block matchers excepted).
- [ ] Each `it` description states an observable behaviour ("notifies the listener of success"),
      not "works".

## Coverage
- [ ] `when successful` asserts both the side effect AND the success callback.
- [ ] `when validation fails` asserts the failure callback.
- [ ] Persistence failure path covered (`when … raises`) where the object writes.
- [ ] Domain branches covered: not-found, not-authorized, ownership, etc.

## Assertions
- [ ] Callback assertions use the let names, not literal symbols, and include `.with(...)`.
- [ ] Collaborator interactions asserted with `have_received` (and `not_to have_received` for
      paths that must not run).
- [ ] No `first_args`; failure payloads checked via `.with(errors:)` or by reading the record.

## Doubles
- [ ] Collaborators doubled with `instance_spy`/`instance_double`/`class_double`.
- [ ] The object under test is never stubbed.
- [ ] Doubles expose only the methods actually called.
