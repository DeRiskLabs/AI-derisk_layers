---
name: testing-user-stories
title: Testing User Stories
description: Spec pattern for Layers user stories (UserStories::*) - orchestration objects that compose forms, use cases, and queries and report via listener callbacks. Use when writing or modifying specs under spec/user_stories.
category: testing
status: active
version: 1.1
applies_to:
  - Ruby
  - Rails
  - RSpec
  - always_execute
  - Layers::BaseLayer
priority: REQUIRED
triggers:
  - user story spec
  - UserStories spec
  - graphql user story spec
  - orchestration object spec
anti_triggers:
  - use case spec
  - model spec
  - request spec
user_invocable: true
last_reviewed_at: 2026-06-03
---


# Testing User Stories

User stories (`UserStories::*`, e.g. `UserStories::Graph::Articles::Update`) are
`Layers::BaseLayer` subclasses that orchestrate a unit of user-facing behaviour — finding
records, authorizing, and composing forms / use cases / queries — and report the outcome by
message passing to a `listener`.


## Required Reading

```text
common_agent_skills/derisk_ruby/ruby-testing/SKILL.md
common_agent_skills/derisk_ruby/always-execute-rspec/SKILL.md
common_agent_skills/derisk_layers/testing-use-cases/SKILL.md
common_agent_skills/derisk_layers/testing-use-cases/references/doubles-and-matchers.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # a full user-story spec, annotated
references/checklist.md           # pre-merge review checklist
```

Authoring the objects under test: [[authoring-user-stories]].


## Same Mechanics as Use Cases

The listener setup, the `params` layering
(`valid_listener_args` + `valid_use_case_args` → `valid_params` → `params`), the
`describe '.call'` + `execute { user_story.call }` structure, and one-expectation `it`s are
**identical** to [[testing-use-cases]]. Read that skill for the mechanics; this skill covers
what is specific to user stories.


## What Is Specific to User Stories

1. **Orchestration paths, not just CRUD.** Cover each branch the story can take: success,
   validation failure, not-found, not-authorized, and "belongs to another user".

2. **Inputs are public identifiers.** Stories are driven by delivery adapters, so lookup
   inputs are uuids (`id: article.uuid`); the not-found branch overrides with a random
   uuid:

   ```ruby
   context 'when the article does not exist' do
     let(:id) { SecureRandom.uuid }

     it 'notifies the listener of failure' do
       expect(listener).to have_received(on_failure_callback)
     end
   end
   ```

3. **Failures carry an `errors` array.** User stories typically report
   `failure(errors: [...])` or `failure(errors: model.errors)`. Assert the listener was
   notified, and (separately) that the error content is right by reading the model the story
   acted on — not via undefined spy helpers.

4. **Integration style is common.** Because stories touch several collaborators and the DB,
   `FactoryBot.create` + `reload` reads cleanly:

   ```ruby
   context 'when successful' do
     it 'updates the article title' do
       article.reload
       expect(article.title).to eq(title)
     end

     it 'notifies the listener of success' do
       expect(listener).to have_received(on_success_callback).with(result: article)
     end
   end
   ```

5. **Composed use cases / queries can be mocked.** When a story delegates to a use case, stub
   its constructor and assert the message, exactly as in [[testing-use-cases]].


## Avoid

- `listener.on_failure.first_args[:errors]` — not a real API. To assert error content,
  inspect the record the story mutated (e.g. `article.errors.full_messages`) in its own
  `it`, or assert `have_received(on_failure_callback).with(errors: ...)`.
- numeric `id`s as story inputs — the public identifier is the uuid.
- multiple expectations per `it`; setup or `#call` inside an `it`.


## Preferred Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserStories::Graph::Articles::Update do
  subject(:user_story) { described_class.new(**params) }

  let(:listener) { instance_spy('Listener') }
  let(:on_success_callback) { :on_success }
  let(:on_failure_callback) { :on_failure }
  let(:valid_listener_args) do
    { listener: listener, on_failure: on_failure_callback, on_success: on_success_callback }
  end

  let(:author)  { FactoryBot.create(:identity) }
  let(:article) { FactoryBot.create(:article, author: author) }
  let(:id)      { article.uuid }
  let(:title)   { 'Updated Title' }
  let(:valid_use_case_args) do
    { current_identity: author, id: id, title: title }
  end
  let(:valid_params) { valid_listener_args.merge(valid_use_case_args) }
  let(:params) { valid_params }


  describe '.call' do
    execute do
      user_story.call
    end

    context 'when successful' do
      it 'notifies the listener of success' do
        expect(listener).to have_received(on_success_callback).with(result: article)
      end
    end

    context 'when the article belongs to another identity' do
      let(:article) { FactoryBot.create(:article, author: FactoryBot.create(:identity)) }

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback)
      end
    end
  end
end
```
