---
name: authoring-graphql-mutations
title: Authoring GraphQL Mutations
description: How to write a declarative GraphQL mutation - an ApplicationMutation subclass that declares arguments, a payload, and the user story to run via the layers gem's user_story DSL. Use when adding or changing files under apis/graph/app/graphql/graph/mutations.
category: architecture
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - GraphQL
  - Layers::Graphql::BaseEndpoint
priority: REQUIRED
triggers:
  - write a graphql mutation
  - new mutation
  - user_story mutation
  - mutation payload errors
anti_triggers:
  - graphql query
  - graphql resolver
  - rest controller
  - use case internals
user_invocable: true
last_reviewed_at: 2026-06-03
---


# Authoring GraphQL Mutations

A mutation is a **pure declaration**: arguments in, payload out, and one line naming the
user story that does the work. The layers gem (`Layers::Graphql::BaseEndpoint`, included
via `ApplicationMutation`) supplies all the machinery.


## Required Reading

```text
common_agent_skills/derisk_layers/authoring-graphql/SKILL.md
common_agent_skills/derisk_layers/authoring-user-stories/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # a full mutation + its user story, annotated
references/checklist.md           # authoring checklist
```

Test with [[testing-graphql]] — acceptance specs only.


## Anatomy

1. Inherit `Graph::Mutations::ApplicationMutation`; place under
   `mutations/<domain>/<action>.rb`.
2. `description` — every mutation has one.
3. `argument`s with project scalar types and descriptions — only client-supplied values.
4. Payload: `field :<resource>, ...` + `field :errors, [Types::Base::ErrorType]`.
5. `user_story 'user_stories/graph/<domain>/<action>'` — the behaviour, by name.
6. `user_story_arg :current_identity` — trusted inputs drawn from `context`.
7. `on_success` / `on_failure` — return the payload hash, nothing more.
8. Register in `MutationType`: `field :create_article, mutation: Graph::Mutations::Articles::CreateArticle`.

```ruby
# frozen_string_literal: true

module Graph
  module Mutations
    module Articles
      class CreateArticle < Graph::Mutations::ApplicationMutation
        description 'Creates a new article'

        argument :title, String, required: true,
          description: 'The title of the article'

        field :article, Types::Articles::Type, null: true,
          description: 'The created article'
        field :errors, [Types::Base::ErrorType], null: true,
          description: 'Errors encountered during article creation'

        user_story 'user_stories/graph/articles/create'
        user_story_arg :current_identity

        def on_success(article: nil)
          {
            article: article,
            errors: []
          }
        end

        def on_failure(errors: nil)
          {
            article: nil,
            errors: execution_errors_for(errors)
          }
        end
      end
    end
  end
end
```


## How It Runs

`BaseEndpoint#resolve` receives the client arguments, merges in the `user_story_arg`
values, and calls the user story with `listener: self, on_success: :success,
on_failure: :failure`. The story calls back exactly one of your two methods with keyword
arguments; the hash you return is the GraphQL payload.


## Rules

- The mutation contains no business logic — find/authorize/orchestrate is the user story's
  job; validate/build is the form's; persist is the use case's.
- The payload field is named after the resource (`article:`), paired with `errors:`.
- `on_failure` maps errors through the base's `execution_errors_for`, producing the uniform
  `{ message, path }` shape.
- `user_story_arg` values come from `context` (the base's private readers), never from
  client arguments.


## Avoid

- logic in `resolve`, `on_success`, or `on_failure` beyond shaping the payload.
- accepting identity/authorization as a client argument.
- hand-rolled error hashes that bypass `execution_errors_for` / `ErrorType`.
- unit specs for the mutation — acceptance specs only ([[testing-graphql]]).
