# Review Checklist — User Story Specs

Builds on the use-case checklist; adds the orchestration-specific items.

## Shared with use cases
- [ ] `# frozen_string_literal: true` + `require 'rails_helper'`.
- [ ] Named `subject`, listener `instance_spy`, callback lets, `params` layering.
- [ ] `describe '.call'` + single `execute`; action nowhere else.
- [ ] One expectation per `it`; no setup/stubbing/action in `it` (block matchers excepted).

## Orchestration coverage
- [ ] A `context` for each branch the story can take:
  - [ ] `when successful`
  - [ ] `when validation fails`
  - [ ] `when the record does not exist` (covers out-of-reach records — identity
        scoping makes off-limits look absent)
- [ ] Engine-resident stories: whole registries swapped for fakes in a `before`;
      effects asserted as outgoing messages (`have_received` + `with`); no factories,
      no database.
- [ ] Container-resident stories: success asserts both the persisted effect (via
      `reload`) and the success callback.
- [ ] Failure branches assert the failure callback.

## Assertions
- [ ] Lookup inputs are uuids (`id: record.uuid`); not-found overrides with `SecureRandom.uuid`.
- [ ] Effects asserted by reading real records (`reload`, container stories) or by
      outgoing messages (engine stories) — never by inspecting internals.
- [ ] "did not change" uses a block matcher: `expect { call }.not_to change { record.reload.x }`.
- [ ] No `first_args`; error content read from the record's `errors`.
- [ ] Composed use cases, when mocked, asserted with `have_received(:call)`.
