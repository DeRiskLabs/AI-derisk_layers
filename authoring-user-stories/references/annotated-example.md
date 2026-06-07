# Annotated Example — User Story

Neutral domain: `UserStories::Graph::Articles::Update` — update an article the current
identity authored. An **engine-resident** story, so collaborators arrive through the
engine's injected registries (doctrine ruling 15). The companion spec is the annotated
example in [[testing-user-stories]].

```ruby
# frozen_string_literal: true

module UserStories
  module Graph
    module Articles
      class Update < UserStories::Graph::Base   # Base < Layers::BaseLayer + ActiveModel::Validations
        # Declare exactly the inputs the action needs. Lookups arrive as public uuids.
        required :current_identity
        required :id
        optional :title

        # The outbound contract: named object on success, errors on failure.
        emits success: [:article], failure: [:errors]

        def call
          # 1. Find — by uuid through the identity-scoped query. Authorization is
          #    reach, not flags: an off-limits article is simply not found.
          return failure(errors: ['Article not found']) unless article

          # 2. Do the work by sending the command to the registered use case,
          #    with this story as the listener.
          update_article.call(
            article: article,
            title: title,
            listener: self,
            on_success: :update_succeeded,
            on_failure: :update_failed,
          )
        end

        # 3. Re-emit the outcome to the story's own listener (the endpoint).
        def update_succeeded(article:)
          success(article: article)
        end

        def update_failed(form: nil, errors: nil)
          failure(errors: errors || form.errors)   # the failure contract: renderable errors
        end


        private

        # Memoized scoped lookup. The registry returns the container's query object
        # class; the engine never names it.
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


## Why these choices

- **Guard-clause sequence.** `#call` reads top-to-bottom as the story: found? then act.
  Each failure mode returns early with a clear `errors:` payload.
- **uuid lookups, identity-scoped.** The story is driven by delivery adapters, so `id` is
  the public uuid; the scope hides other identities' records, so off-limits is
  indistinguishable from absent — no "not authorized" oracle
  ([[api-authentication-authorization]]).
- **Registries, not constants.** `Graph.configuration.queries[:articles]` /
  `.use_cases[:update_article]` — the container binds these in
  `config/initializers/graph.rb`. One static container-constant reference would break
  the engine's standalone schema-less suite ([[authoring-engines]]).
- **`errors:` payload.** GraphQL endpoints and controllers render these; user stories
  standardise on an errors array or an `errors` object so the endpoint stays dumb.
- **Action-named callbacks.** `update_succeeded`/`update_failed`, never
  `on_success`/`on_failure` — those names are `Layers::BaseLayer`'s callback-name
  readers; overriding them breaks outcome dispatch.
- **Delegate real work.** The transactional write lives in the use case; the story
  orchestrates and re-emits.
