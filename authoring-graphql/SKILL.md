---
name: authoring-graphql
title: Authoring GraphQL Endpoints
description: Hub for the GraphQL delivery layer - engine anatomy, base classes wiring Layers::Graphql::BaseEndpoint, base and domain types, schema wiring, and the acceptance-only testing strategy. Use when adding or changing files under an apis/graph engine.
category: architecture
status: active
version: 2.2
applies_to:
  - Ruby
  - Rails
  - GraphQL
  - Layers::Graphql::BaseEndpoint
priority: REQUIRED
triggers:
  - graphql engine
  - graphql type
  - application mutation base
  - application resolver base
  - graph schema wiring
anti_triggers:
  - rest controller
  - use case internals
  - model logic
user_invocable: true
last_reviewed_at: 2026-06-04
---


# common_agent_skills/derisk_layers/authoring-graphql/SKILL.md


# Authoring GraphQL Endpoints

The GraphQL layer is a **thin, declarative delivery adapter**. Mutations and resolvers
declare arguments, a payload, and which user story runs — nothing else. Behaviour lives in
user stories ([[authoring-user-stories]]); shape lives in types. `Layers::Graphql::BaseEndpoint`
provides all the machinery.


## Required Reading

```text
common_agent_skills/derisk_layers/rails-app-architecture/SKILL.md
common_agent_skills/derisk_layers/authoring-user-stories/SKILL.md
```

Authoring the endpoints themselves:

```text
[[authoring-graphql-mutations]]   # declarative mutations
[[authoring-graphql-queries]]     # declarative query resolvers
```

Supporting references in this skill:

```text
references/engine-anatomy.md   # base classes, types, and schema wiring, annotated
references/checklist.md        # shared boundaries checklist
```

Test with [[testing-graphql]] — acceptance specs only (see Testing Strategy).


## Engine Anatomy

```text
apis/graph/app/
  graphql/graph/
    platform_schema.rb                # GraphQL::Schema; query/mutation roots
    types/query_type.rb               # field :articles, resolver: Resolvers::Articles::Articles
    types/mutation_type.rb            # field :create_article, mutation: Mutations::CreateArticle
    types/base/                       # Argument, Field, Object, Enum, Scalar, ErrorType, UuidType, ...
    types/<domain>/type.rb            # domain object types
    mutations/application_mutation.rb # base: includes Layers::Graphql::BaseEndpoint
    mutations/<domain>/<action>.rb    # concrete mutations
    resolvers/application_resolver.rb # base: includes Layers::Graphql::BaseEndpoint
    resolvers/<domain>/<name>.rb      # concrete resolvers
  lib/user_stories/graph/             # the user stories the endpoints declare
```

User stories are boundaries of the graph API, so they live inside the engine at
`apis/graph/app/lib/user_stories/graph/<domain>/<action>.rb` (see [[authoring-user-stories]]).


## The Base Classes

`ApplicationMutation` and `ApplicationResolver` are where `Layers::Graphql::BaseEndpoint`
is mixed in — concrete endpoints only declare:

```ruby
module Graph
  module Mutations
    class ApplicationMutation < GraphQL::Schema::Mutation
      include Layers::Graphql::BaseEndpoint

      argument_class Graph::Types::Base::Argument
      field_class Graph::Types::Base::Field
      object_class Graph::Types::Base::Object


      private

      def current_identity
        context[:current_identity]
      end

      def current_user_account
        context[:current_user_account]
      end

      # execution_errors_for(errors) maps model/form errors to { message:, path: }
    end
  end
end
```

`BaseEndpoint#resolve` captures the client arguments, then runs the declared user story with
`listener: self, on_success: :success, on_failure: :failure`, merging in the trusted
`user_story_arg` values. The endpoint's `on_success` / `on_failure` shape the response.


## Types

Types are pure declarations — `field` lines with descriptions, no logic:

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
      end
    end
  end
end
```

Errors always travel as `Types::Base::ErrorType` (`message` + `path`).


## Layer Map

| Concern                       | Lives in                                  |
| ----------------------------- | ----------------------------------------- |
| Arguments, payload, delegation| the mutation/resolver (pure declaration)  |
| Find, authorize, orchestrate  | the user story                            |
| Validation, building          | the form ([[authoring-form-objects]])     |
| Persistence                   | the use case ([[authoring-use-cases]])    |
| Response shape                | the types                                 |


## Testing Strategy

GraphQL endpoints and types are declarative enough that they get **acceptance specs only**
([[testing-graphql]]) — a document posted to `/graphql` exercises schema → endpoint →
user story end to end.

- Do NOT write unit specs for concrete mutations, resolvers, or types.
- The machinery — `Layers::Graphql::BaseEndpoint` and the DSL mixins — is tested
  exhaustively in the layers gem ([[testing-layers-base-classes]]).
- The behaviour is unit-tested in the user story's spec ([[testing-user-stories]]).


## Rules

- Endpoints contain no business logic — they map GraphQL ⇄ user story and format errors.
- `user_story_arg` pulls trusted values (the authenticated identity) from `context`, never
  from client input.
- Keep types thin; put any field logic on the type, not in the endpoint.
- Every mutation/resolver follows the declarative shape — if an endpoint needs more, the
  missing piece belongs in the user story.


## Avoid

- doing domain work in `resolve`/`on_success` — delegate to the user story.
- trusting client-supplied identity/authorization args; derive them from `context`.
- divergent error shapes — reuse the base's error mapping and `ErrorType`.
- unit specs for concrete endpoints or types (acceptance only).
