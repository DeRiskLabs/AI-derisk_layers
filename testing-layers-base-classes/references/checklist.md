# common_agent_skills/derisk_layers/testing-layers-base-classes/references/checklist.md


# Review Checklist — Layers Base Class / DSL Module Specs

Apply on top of the general checklist in derisk_ruby/testing-base-classes.


## Setup

- [ ] `require 'layers_spec_helper'` (gem) or `rails_helper` (app), as appropriate.
- [ ] Host constants stubbed where touched: `ActiveRecord::Relation`,
      `GraphQL::ExecutionError` (or configured via `Layers.configure`), user story
      classes via `stub_const`.
- [ ] `Layers.configuration` reset after every example that touches it (ideally a
      helper-level `config.after`).


## Contract coverage

- [ ] Composition pinned for every promised DSL module (`Observers`, `Inputs`,
      `NullListener`, `CallbackDefaults`, `ClassCallable`).
- [ ] Null listener default asserted (`be_a(Naught::BasicObject)`).
- [ ] Callback defaults asserted (`on_success` equals `on_success_default`); custom
      callbacks win when passed.
- [ ] Custom listener identity asserted with `be`, not `eq`.
- [ ] Inputs validation raises `Layers::DSL::MissingRequiredInputs` /
      `Layers::DSL::UnexpectedInputs` (block-expectation form).
- [ ] success/failure exercised through a concrete subclass `#call` — no `send` to
      private reporting methods, no `expect(layer).to receive(:notify_observers)`.
- [ ] Observer notification asserted behaviourally (callable observer recording into a
      local).


## App base classes

- [ ] Pins inheritance (`ancestors` includes `Layers::BaseLayer`) and app additions only
      (callback default overrides, extra includes).
- [ ] Does not re-test gem behaviour (inputs validation, null listener, observer
      mechanics).


## GraphQL

- [ ] App GraphQL tested acceptance-only (testing-graphql); only an app endpoint *base
      class* gets a spec here, pinning app additions only.
