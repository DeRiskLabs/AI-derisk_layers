---
name: authoring-user-stories
title: Authoring User Stories
description: How to write a user story - a Layers::BaseLayer subclass that orchestrates one unit of user-facing behaviour (find, authorize, compose forms/use-cases/queries) and reports via success/failure. Use when adding or changing classes under a boundary's app/lib/user_stories.
category: architecture
status: active
version: 1.7
applies_to:
  - Ruby
  - Rails
  - Layers::BaseLayer
priority: REQUIRED
triggers:
  - write a user story
  - new user story
  - UserStories class
  - graphql orchestration object
anti_triggers:
  - single transactional use case
  - query object
  - form object
user_invocable: true
last_reviewed_at: 2026-06-07
---


# Authoring User Stories

A user story is a `Layers::BaseLayer` subclass that orchestrates **one unit of user-facing
behaviour**: find the records, authorize the actor, then compose forms, use cases, and query
objects to satisfy the request. It is the entry point a delivery mechanism (GraphQL endpoint,
controller) drives, and it reports via message passing.

In ports-and-adapters terms, a user story is **the boundary of the user interaction**: the
way out of the delivery layer (controller stack, GraphQL endpoint, any user interaction
point) into the business-logic layer and back. That is why the delivery adapter calls a
user story — crossing it exits Rails/GraphQL entirely.


## Required Reading

```text
common_agent_skills/derisk_layers/layered-architecture-placement/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # a full user story, annotated
references/checklist.md           # authoring checklist
```

Test it with [[testing-user-stories]]. Composes [[authoring-use-cases]],
[[authoring-form-objects]], [[authoring-query-objects]].


## Placement and Naming

A user story lives in the boundary that owns it, under that boundary's
`app/lib/user_stories/`. Graph-facing user stories are boundaries of the graph API, so they
live inside the graph engine:

```text
apis/graph/app/lib/user_stories/graph/<domain>/<action>.rb  →  UserStories::Graph::<Domain>::<Action>
```

The engine's `app/lib` is an autoload root, so the constants and the
`user_story 'user_stories/graph/...'` declaration strings are unaffected by which boundary
holds the file.

A thin base sits above `Layers::BaseLayer`:
`UserStories::Graph::Base < Layers::BaseLayer` (adds `include ActiveModel::Validations`).
Engines define their own base, e.g. `<Engine>::BaseUserStory < Layers::BaseLayer`.

Scaffold the object + spec pair with
`bin/rails generate layers:user_story <domain>/<action>` — never hand-create files a
generator scaffolds; fill the generated TODOs.


## Anatomy

1. Inherit from the relevant base (`UserStories::Graph::Base` / `<Engine>::BaseUserStory`).
2. Declare inputs with `required` / `optional` (e.g. `required :current_identity, :id`).
3. Implement `#call` as an orchestration with explicit guard clauses:
   - find the record(s); `return failure(errors: ['... not found']) unless record`
   - authorize; `return failure(errors: ['Not authorized ...']) unless authorized?(record)`
   - perform the work (often by delegating to a use case or query object)
   - `success(article: article)` / `failure(errors: article.errors)` — the success payload
     key **names the object it carries**; there is no such thing as a "result"

```ruby
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


## Rules

- A user story spans the **whole** user action; a use case is the single transactional step
  inside it. If there is no orchestration (just one transactional write), write a use case.
- Only delivery adapters (user interaction points) call user stories. Use cases, jobs, and
  other internal actors never do — a user story is the interaction boundary, not a shared
  internal helper.
- Declarations are per-class: `required`/`optional`, `observer`, and `default_callbacks`
  apply only to the declaring class — nothing inherits. State the complete contract in
  the concrete class; keep base classes behavioural (includes, shared private helpers).
- Report through `success(...)` / `failure(...)` only. A failure payload always carries
  the means to render errors: an object responding to `.errors`, or an errors collection
  itself (e.g. `failure(errors: [...])`) — the endpoint renders without knowing what
  failed.
- Authorization and "does it exist" live here, not in the use case.
- Keep `#call` a readable sequence of guards + one happy path. Push detail into private
  methods or collaborators.
- No HTTP/GraphQL response shaping — that is the endpoint's job (the user story is the
  listener's target).


## Avoid

- duplicating transactional write logic that belongs in a use case — delegate to it.
- inline complex queries — use a query object ([[authoring-query-objects]]).
- returning values instead of sending `success`/`failure`.
- a generic `result` payload key — payloads carry **named objects or errors**. Result-speak
  seeds Result-object patterns, which metastasize through a codebase.
