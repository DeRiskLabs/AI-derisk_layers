# Annotated Example — User Story Spec

Neutral domain: `UserStories::Graph::Articles::Update` — find an article by uuid, authorize
the current identity, update it, and report via the listener. User stories are
integration-leaning, so this uses real records via FactoryBot.


## The Object Under Test

The user story being specced, compact — the fully annotated version is the annotated
example in [[authoring-user-stories]]:

```ruby
# frozen_string_literal: true

module UserStories
  module Graph
    module Articles
      class Update < UserStories::Graph::Base
        required :current_identity
        required :id
        optional :title

        def call
          article = Article.find_by(uuid: id)
          return failure(errors: ['Article not found']) unless article
          return failure(errors: ['Not authorized to update this article']) unless authorized?(article)

          if article.update(update_attributes)
            success(article: article)
          else
            failure(errors: article.errors)
          end
        end

        private

        def authorized?(article)
          article.author == current_identity
        end

        def update_attributes
          {}.tap { |a| a[:title] = title if title.present? }
        end
      end
    end
  end
end
```


## The Spec

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserStories::Graph::Articles::Update do
  subject(:user_story) { described_class.new(**params) }

  # Same listener contract as a use case (see testing-use-cases).
  let(:listener) { instance_spy('Listener') }
  let(:on_success_callback) { :on_success }
  let(:on_failure_callback) { :on_failure }
  let(:valid_listener_args) do
    { listener: listener, on_failure: on_failure_callback, on_success: on_success_callback }
  end

  # Integration style: real records. The story finds by uuid (the public identifier),
  # authorizes by ownership, mutates.
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
      # Read the persisted record to assert the effect; assert the callback separately.
      it 'updates the article title' do
        article.reload
        expect(article.title).to eq(title)
      end

      it 'notifies the listener of success' do
        expect(listener).to have_received(on_success_callback).with(article: article)
      end
    end

    context 'when validation fails' do
      let(:title) { '' }

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback)
      end

      it 'does not change the title' do
        expect { user_story.call }.not_to change { article.reload.title }
      end
    end

    context 'when the article does not exist' do
      let(:id) { SecureRandom.uuid }

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback)
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


## Why these choices

- **One context per orchestration branch.** A user story's value is the decision tree it
  walks (found? authorized? valid?). Each branch is a `context` ending in the right callback.
- **uuid inputs.** The story is driven by delivery adapters, so its lookup input is the
  public identifier (`id: article.uuid`); the not-found branch overrides with a random uuid.
- **Integration over heavy mocking.** Stories touch several collaborators and the database;
  real records via `FactoryBot.create` read more clearly than mocking each step. Mock a
  composed use case only when you specifically want to assert it was invoked.
- **Effect and notification are separate examples.** "updates the title" reads the record;
  "notifies the listener" asserts the spy. One behaviour each.
- **"did not change" via a block matcher** — the delta-assertion exception.
- **Error content without `first_args`.** If you must assert the error message, read it from
  the record the story acted on (`article.errors.full_messages`) in its own `it`.
