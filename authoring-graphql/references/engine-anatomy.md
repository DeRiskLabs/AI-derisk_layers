# Engine Anatomy — Base Classes, Types, and Schema Wiring

The shared skeleton every endpoint builds on. Concrete mutations and resolvers are in
[[authoring-graphql-mutations]] and [[authoring-graphql-queries]].


## The Base Mutation

```ruby
# frozen_string_literal: true

module Graph
  module Mutations
    class ApplicationMutation < GraphQL::Schema::Mutation
      include Layers::Graphql::BaseEndpoint   # user_story DSL + resolve machinery

      # Wire the project base types so every argument/field/object goes through them.
      argument_class Graph::Types::Base::Argument
      field_class Graph::Types::Base::Field
      object_class Graph::Types::Base::Object


      private

      # Trusted values for user_story_arg — always from context, never client input.
      def current_authorization
        context[:current_authorization]
      end

      def current_user_account
        context[:current_user_account]
      end

      # Maps model/form errors to the uniform { message:, path: } shape, building the
      # path from the GraphQL operation + the error's base class + attribute.
      def execution_errors_for(errors)
        errors.map do |error|
          next if error.is_a?(GraphQL::ExecutionError)

          error_attr = execution_error_attr(error)
          error_base = execution_error_base(error)

          path = context.current_path.dup
          path << error_base if error_base
          path << error_attr if error_attr

          message = error_attr == 'base' ? '' : "#{error_attr}: "
          message += error.message

          { message: message, path: path }
        end.compact
      end

      def execution_error_attr(error)
        return unless error.respond_to?(:attribute)
        error.attribute.to_s.camelize(:lower)
      end

      def execution_error_base(error)
        return unless error.respond_to?(:base)
        error.base.class.name
      end
    end
  end
end
```


## The Base Resolver

```ruby
# frozen_string_literal: true

module Graph
  module Resolvers
    class ApplicationResolver < GraphQL::Schema::Resolver
      include Layers::Graphql::BaseEndpoint


      private

      def current_user_account
        context[:current_user_account]
      end

      def current_authorization
        context[:current_authorization]
      end
    end
  end
end
```


## What BaseEndpoint Provides

From the layers gem (`Layers::Graphql::BaseEndpoint`):

- `user_story 'user_stories/graph/articles/create'` — declares the story (camelized and
  constantized at resolve time).
- `user_story_arg :current_authorization` — merges the named private method's value into the
  story's inputs; raises `InvalidUserStoryArgumentMethod` if the method is missing.
- `#resolve(**args)` — captures client args, runs the story with
  `listener: self, on_success: :success, on_failure: :failure`, and MASKS any raised
  error: the source error is logged with backtrace, the client receives a
  `GraphQL::ExecutionError` carrying only `Layers.configuration.masked_error_message`.
  Execution-error instances and the gem's wiring errors (`InvalidUserStory`,
  `InvalidUserStoryArgumentMethod`) pass through as themselves; `exposed_error_classes`
  allowlists safe domain errors; `reveal_masked_errors` (e.g. `Rails.env.local?`)
  restores full messages in development.
- `success`/`failure` forward to the `on_success`/`on_failure` you implement
  (`NotImplementedError` otherwise).


## The Error Type

```ruby
module Graph
  module Types
    module Base
      class ErrorType < Graph::Types::Base::Object
        description 'An error message'

        field :message, String, null: false,
          description: 'The error message'
        field :path, [String], null: true,
          description: 'The path to the error'
      end
    end
  end
end
```


## Domain Types

Pure declarations — fields with descriptions, project scalars (`UuidType`,
`GraphQL::Types::ISO8601DateTime`), no logic:

```ruby
module Graph
  module Types
    module Articles
      class Type < Graph::Types::Base::Object
        description 'A published or draft article'

        field :id, Types::Base::UuidType, null: false,
          description: 'The unique identifier for the article'
        field :title, String, null: false,
          description: 'The article title'
        field :status, String, null: false,
          description: 'The publication status'
        field :author, Graph::Types::Identities::Type, null: false,
          description: 'The identity who wrote this article'
        field :created_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: 'When this article was created'
      end
    end
  end
end
```


## Schema Wiring

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

```ruby
module Graph
  module Types
    class MutationType < Graph::Types::Base::Object

      field :create_article, mutation: Graph::Mutations::Articles::CreateArticle

    end
  end
end
```
