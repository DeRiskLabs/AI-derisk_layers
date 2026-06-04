# common_agent_skills/derisk_layers/authoring-graphql-queries/references/annotated-example.md


# Annotated Example — GraphQL Query Resolvers

Neutral domain: `articles` (list) and `article` (single). The resolver declares; the user
story fetches and scopes. The acceptance spec exercising this pair is the annotated query
example in [[testing-graphql]].


## The List Resolver

```ruby
# frozen_string_literal: true

module Graph
  module Resolvers
    module Articles
      class Articles < Graph::Resolvers::ApplicationResolver  # includes BaseEndpoint
        description 'Fetches articles the current user has access to'

        # Lists return a non-null array of the domain type.
        type [Types::Articles::Type], null: false

        # The behaviour, by name; identity from context — never a client argument.
        user_story 'user_stories/graph/articles/fetch_all'
        user_story_arg :current_identity

        # Queries return the result DIRECTLY — no payload hash.
        def on_success(result: nil)
          result
        end

        # Failures surface as GraphQL execution errors.
        def on_failure(errors: nil)
          errors&.map do |error|
            GraphQL::ExecutionError.new(error.message)
          end
        end
      end
    end
  end
end
```


## The Single Resolver

```ruby
# frozen_string_literal: true

module Graph
  module Resolvers
    module Articles
      class Article < Graph::Resolvers::ApplicationResolver
        description 'Fetches a single article by ID'

        # The lookup key is the only client argument.
        argument :id, Types::Base::UuidType, required: true,
          description: 'The UUID of the article to fetch'

        type Types::Articles::Type, null: true

        user_story 'user_stories/graph/articles/fetch'
        user_story_arg :current_identity

        def on_success(result: nil)
          result
        end

        def on_failure(errors: nil)
          errors&.map do |error|
            GraphQL::ExecutionError.new(error.message)
          end
        end
      end
    end
  end
end
```


## The User Stories They Run

Compact — authored per [[authoring-user-stories]]. **Scoping lives here**, driven by
`current_identity`:

```ruby
# frozen_string_literal: true

module UserStories
  module Graph
    module Articles
      class FetchAll < UserStories::Graph::Base
        required :current_identity

        def call
          articles = Article.where(author: current_identity)

          success(result: articles)
        end
      end
    end
  end
end
```

```ruby
# frozen_string_literal: true

module UserStories
  module Graph
    module Articles
      class Fetch < UserStories::Graph::Base
        required :current_identity
        required :id

        def call
          article = Article.where(author: current_identity).find_by(uuid: id)

          if article
            success(result: article)
          else
            failure(errors: [StandardError.new('Article not found')])
          end
        end
      end
    end
  end
end
```


## Wiring

```ruby
module Graph
  module Types
    class QueryType < Graph::Types::Base::Object
      description 'The query root of this schema'

      field :articles, [Graph::Types::Articles::Type],
            resolver: Graph::Resolvers::Articles::Articles,
            null: true

      field :article, Graph::Types::Articles::Type,
            resolver: Graph::Resolvers::Articles::Article,
            null: true
    end
  end
end
```


## Why these choices

- **Result returned directly.** Unlike mutations, the resolver's return value IS the field
  value; GraphQL nulls/errors handle the failure channel via `GraphQL::ExecutionError`.
- **Scoping in the story, not the resolver.** `Article.where(author: current_identity)` is
  behaviour — it belongs with the user story, where it is unit-tested
  ([[testing-user-stories]]) and exercised by the acceptance spec's scoping case.
- **Plural/singular resolver pairs.** `Articles::Articles` and `Articles::Article` mirror
  the two field shapes a domain usually exposes.
- **No unit spec.** The declaration is exercised end-to-end by its acceptance spec; the
  machinery is tested in the layers gem; the behaviour in the user story's spec.
