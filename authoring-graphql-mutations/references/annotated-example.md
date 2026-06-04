# common_agent_skills/derisk_layers/authoring-graphql-mutations/references/annotated-example.md


# Annotated Example — GraphQL Mutation

Neutral domain: `createArticle`. The mutation declares; the user story behaves. The
acceptance spec exercising this pair is the annotated mutation example in
[[testing-graphql]].


## The Mutation

```ruby
# frozen_string_literal: true

module Graph
  module Mutations
    module Articles
      class CreateArticle < Graph::Mutations::ApplicationMutation  # includes BaseEndpoint
        description 'Creates a new article'

        # Only client-supplied values are arguments. Project scalars + descriptions.
        argument :title, String, required: true,
          description: 'The title of the article'

        # Payload: the resource, named for itself, plus the uniform errors list.
        field :article, Types::Articles::Type, null: true,
          description: 'The created article'
        field :errors, [Types::Base::ErrorType], null: true,
          description: 'Errors encountered during article creation'

        # The behaviour, by name. BaseEndpoint constantizes and runs it with
        # listener: self — the mutation never implements the behaviour.
        user_story 'user_stories/graph/articles/create'

        # Trusted input from context (via the base's private reader) — the client
        # cannot supply or override it.
        user_story_arg :current_identity

        # The story calls back exactly one of these. Return value = GraphQL payload.
        def on_success(article: nil)
          {
            article: article,
            errors: []
          }
        end

        def on_failure(errors: nil)
          {
            article: nil,
            errors: execution_errors_for(errors)   # uniform { message, path } mapping
          }
        end
      end
    end
  end
end
```


## The User Story It Runs

Compact — authored per [[authoring-user-stories]], unit-tested per [[testing-user-stories]]:

```ruby
# frozen_string_literal: true

module UserStories
  module Graph
    module Articles
      class Create < UserStories::Graph::Base
        required :current_identity
        required :title

        def call
          article = Article.new(title: title, author: current_identity)

          if article.save
            success(article: article)
          else
            failure(errors: article.errors)
          end
        end
      end
    end
  end
end
```

Note the contract: the story's `success(article: ...)` keyword matches `on_success(article:)`;
its `failure(errors: ...)` matches `on_failure(errors:)`.


## Registration

```ruby
module Graph
  module Types
    class MutationType < Graph::Types::Base::Object

      field :create_article, mutation: Graph::Mutations::Articles::CreateArticle

    end
  end
end
```


## Why these choices

- **`user_story` + `user_story_arg`.** `BaseEndpoint#resolve` merges client arguments with
  context-derived values and runs the named story with `listener: self`. The mutation is a
  declaration, not an implementation.
- **`current_identity` from context.** Trust is never delegated to client input.
- **Resource-named payload.** Every mutation returns `{ <resource>, errors }`; errors carry
  `message` + `path` via `execution_errors_for`, so clients handle failures uniformly.
- **No unit spec.** The declaration is exercised end-to-end by its acceptance spec; the
  machinery is tested in the layers gem; the behaviour in the user story's spec.
