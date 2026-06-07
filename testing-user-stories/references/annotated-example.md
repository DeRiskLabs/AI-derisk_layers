# Annotated Example — User Story Spec

Neutral domain: `UserStories::Graph::Articles::Update` — find an article through the
engine's registered query object (identity-scoped), send the update command to the
registered use case, report via the listener. An **engine-resident** story, so its suite
runs standalone against a schema-less dummy app: **registry fakes, no database, no
factories** (doctrine ruling 15; see [[authoring-engines]]).


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

        emits success: [:article], failure: [:errors]

        def call
          return failure(errors: ['Article not found']) unless article

          update_article.call(
            article: article,
            title: title,
            listener: self,
            on_success: :update_succeeded,
            on_failure: :update_failed,
          )
        end

        def update_succeeded(article:)
          success(article: article)
        end

        def update_failed(form: nil, errors: nil)
          failure(errors: errors || form.errors)
        end


        private

        def article
          @article ||= articles_query.new(identity: current_identity).find_by(uuid: id)
        end

        def articles_query
          Graph.configuration.queries[:articles]
        end

        def update_article
          Graph.configuration.use_cases[:update_article]
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

  # Registry fakes: the engine's registries are swapped wholesale — anything
  # answering [] serves. The query object and use case are verifying doubles of
  # the contracts the container will bind.
  let(:identity)       { instance_double('Identity') }
  let(:id)             { SecureRandom.uuid }
  let(:title)          { 'Updated Title' }
  let(:article)        { instance_double('Article', errors: article_errors) }
  let(:article_errors) { instance_double('ActiveModel::Errors') }

  let(:update_use_case) { class_spy('UseCases::Articles::Update') }
  let(:articles_query)  { class_double('Queries::ArticlesQuery', new: query_instance) }
  let(:query_instance)  { instance_double('Queries::ArticlesQuery', find_by: article) }

  let(:valid_use_case_args) do
    { current_identity: identity, id: id, title: title }
  end
  let(:valid_params) { valid_listener_args.merge(valid_use_case_args) }
  let(:params) { valid_params }

  before do
    Graph.configuration.use_cases = { update_article: update_use_case }
    Graph.configuration.queries = { articles: articles_query }
  end


  describe '.call' do
    execute do
      user_story.call
    end

    context 'when the article is in reach' do
      # The story's work is two outgoing messages: scope the lookup, send the command.
      it 'scopes the lookup to the current identity' do
        expect(articles_query).to have_received(:new).with(identity: identity)
      end

      it 'sends the update command with itself as listener' do
        expect(update_use_case).to have_received(:call).with(
          article: article,
          title: title,
          listener: user_story,
          on_success: :update_succeeded,
          on_failure: :update_failed,
        )
      end
    end

    context 'when the use case reports success' do
      let(:update_use_case) do
        Class.new do
          def self.call(listener:, on_success:, article:, **)
            listener.public_send(on_success, article: article)
          end
        end
      end

      it 'notifies the listener of success with the named object' do
        expect(listener).to have_received(on_success_callback).with(article: article)
      end
    end

    context 'when the article is not found' do
      let(:query_instance) { instance_double('Queries::ArticlesQuery', find_by: nil) }

      it 'notifies the listener of failure' do
        expect(listener).to have_received(on_failure_callback)
      end

      it 'does not send the update command' do
        expect(update_use_case).not_to have_received(:call)
      end
    end
  end
end
```


## Why these choices

- **One context per orchestration branch.** A user story's value is the decision tree it
  walks (in reach? command outcome?). Each branch is a `context` ending in the right
  callback or outgoing message.
- **uuid inputs.** The story is driven by delivery adapters, so its lookup input is the
  public identifier; not-found covers off-limits records too — authorization is identity
  scoping, so there is no separate "not authorized" branch to test.
- **Whole-registry swap.** `Graph.configuration.use_cases = { ... }` in a `before` —
  never register doubles entry-by-entry. The fake registry is just a hash.
- **Outgoing messages over aftermath.** With no database, the story's effects ARE its
  outgoing commands (Metz grid: outgoing command → `have_received` + `with`). The real
  binding is proven by the container's delivery-level acceptance specs.
- **A tiny callback-driving fake** for the success path: the inline class calls the
  listener back the way the real use case would, letting the spec pin the re-emit
  (`update_succeeded` → `success(article:)`) without booting any domain code.
- **Error content without `first_args`.** Assert
  `have_received(on_failure_callback).with(errors: ...)` where the content matters.

Container-resident stories (in the app's own `app/lib/user_stories/`) live with AR and
may instead use the DB-backed FactoryBot style — see SKILL.md point 5.
