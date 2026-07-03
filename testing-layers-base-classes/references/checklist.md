# Review Checklist — App Base Class Over a Layers Base

Apply on top of the general checklist in derisk_ruby/testing-base-classes. This is for an
app base class (`BaseUseCase`, `BaseUserStory`, `ApplicationQuery`, an app GraphQL endpoint
base) over a Layers base — not the gem's own bases.


## Setup

- [ ] `require 'rails_helper'` (the app spec runs in the app, not the gem).


## Pin only what the app adds

- [ ] Pins inheritance (`ancestors` includes `Layers::BaseLayer`).
- [ ] Pins app additions only: callback-default overrides, extra includes, convenience
      methods the base defines.
- [ ] Does NOT re-test gem behaviour (inputs validation, null listener, callback-defaults
      mechanics, observer notification) — the gem tests its own bases.


## Assert endowment behaviourally

- [ ] Where the base is meant to carry a capability, asserted behaviourally
      (`respond_to`, missing-input `raise_error`) — never structurally via
      `included_modules` (S-AI-027).


## GraphQL

- [ ] App GraphQL tested acceptance-only ([[testing-graphql]]); only an app endpoint *base
      class* gets a spec here, pinning app additions only.
