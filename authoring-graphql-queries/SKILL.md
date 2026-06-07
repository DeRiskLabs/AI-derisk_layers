---
name: authoring-graphql-queries
title: Authoring GraphQL Queries
description: How to write a declarative GraphQL query resolver - an ApplicationResolver subclass that declares arguments, a return type, and the user story to run via the layers gem's user_story DSL. Use when adding or changing files under apis/graph/app/graphql/graph/resolvers.
category: architecture
status: active
version: 1.3
applies_to:
  - Ruby
  - Rails
  - GraphQL
  - Layers::Graphql::BaseEndpoint
priority: REQUIRED
triggers:
  - write a graphql query
  - write a graphql resolver
  - new resolver
  - user_story resolver
anti_triggers:
  - graphql mutation
  - rest controller
  - use case internals
user_invocable: true
last_reviewed_at: 2026-06-07
---


# Authoring GraphQL Queries

A query resolver is a **pure declaration**: optional arguments, a return type, and one line
naming the user story that fetches. The layers gem (`Layers::Graphql::BaseEndpoint`,
included via `ApplicationResolver`) supplies all the machinery.


## Required Reading

```text
common_agent_skills/derisk_layers/authoring-graphql/SKILL.md
common_agent_skills/derisk_layers/authoring-user-stories/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # list + single resolvers and their user stories, annotated
references/checklist.md           # authoring checklist
```

Test with [[testing-graphql]] — acceptance specs only.

Scaffold the resolver + engine-local user story + pending acceptance spec with
`bin/rails generate layers:graphql_query <domain>` (add `--single` for the one-record
resolver) — never hand-create files a generator scaffolds; fill the generated TODOs.


## Anatomy

1. Inherit `Graph::Resolvers::ApplicationResolver`; place under
   `resolvers/<domain>/<name>.rb` — plural class for the list, singular for one record.
2. `description` — every resolver has one.
3. `argument`s for client-supplied lookups (e.g. `:id, Types::Base::UuidType`).
4. `type ..., null:` — the return type (array for lists).
5. `user_story 'user_stories/graph/<domain>/<fetch>'` + `user_story_arg :current_authorization`.
6. `on_success` receives the **named object** the story emits (`articles:` for a list,
   `article:` for one record) and returns it **directly** (not a payload hash). Payload
   keys always name what they carry — never a generic `result` key, which seeds
   Result-object thinking.
7. `on_failure(errors:)` maps to `GraphQL::ExecutionError`s.
8. Wire in `QueryType`: `field :articles, [...], resolver: Graph::Resolvers::Articles::Articles`.

```ruby
# frozen_string_literal: true

module Graph
  module Resolvers
    module Articles
      class Articles < Graph::Resolvers::ApplicationResolver
        description 'Fetches articles the current user has access to'

        type [Types::Articles::Type], null: false

        user_story 'user_stories/graph/articles/fetch_all'
        user_story_arg :current_authorization

        def on_success(articles: nil)
          articles
        end

        def on_failure(articles: nil, errors: nil)
          errors_list = Array(articles ? articles.errors : errors)
          errors_list.map do |error|
            GraphQL::ExecutionError.new(error.message)
          end
        end
      end
    end
  end
end
```

A single-record resolver adds the lookup argument:

```ruby
argument :id, Types::Base::UuidType, required: true,
  description: 'The UUID of the article to fetch'

type Types::Articles::Type, null: true

user_story 'user_stories/graph/articles/fetch'
```


## Mutations vs Queries

| Aspect       | Mutation                                   | Query resolver                          |
| ------------ | ------------------------------------------ | --------------------------------------- |
| Payload      | `field :<resource>` + `field :errors`      | `type ..., null:`                       |
| `on_success` | returns `{ <resource>:, errors: [] }`      | returns the named object directly       |
| `on_failure` | `{ <resource>: nil, errors: [...] }` hash  | array of `GraphQL::ExecutionError`      |
| Wiring       | `MutationType` `mutation:`                 | `QueryType` `resolver:`                 |


## Rules

- **Scoping lives in the user story**, driven by `current_authorization` — the resolver never
  filters. A list story returns only records the identity may see; a fetch story returns
  `nil`/failure for records outside that scope.
- The resolver contains no business logic — it declares and delegates.
- `user_story_arg` values come from `context`, never from client arguments.


## Avoid

- scoping/filtering in the resolver — that is the user story's job.
- returning payload hashes from `on_success` — queries return the named object itself.
- accepting identity/authorization as a client argument.
- unit specs for the resolver — acceptance specs only ([[testing-graphql]]).
