---
name: layered-architecture-placement
title: Layered Architecture and Placement
description: The mental model for the layer abstractions (user stories, use cases, query objects, form objects), what each is responsible for, how they collaborate, and where each file lives. Load when deciding which abstraction to write or where to put it.
category: architecture
status: active
version: 1.2
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - which abstraction
  - where does this go
  - layered architecture
  - ports and adapters
  - separate business logic
anti_triggers:
  - pure framework config
user_invocable: true
last_reviewed_at: 2026-06-04
---


# common_agent_skills/derisk_layers/layered-architecture-placement/SKILL.md

# Layered Architecture and Placement

This is the mental model for separating business logic from framework code, using the
`layers` gem. Use it to decide **which abstraction** to write and **where it lives**, then
follow the specific authoring skill.


## Required Reading

```text
common_agent_skills/derisk_layers/rails-app-architecture/SKILL.md
```

Supporting references in this skill:

```text
references/directory-map.md   # where each abstraction lives
references/request-flow.md     # a request traced through the layers
```


## The Layers (and their authoring skills)

| Layer | Responsibility | Reports / returns | Skill |
| --- | --- | --- | --- |
| Delivery adapter (controller / GraphQL endpoint) | Translate HTTP/GraphQL ⇄ a user story; render | renders response | [[authoring-controllers]], [[authoring-graphql]] |
| User story | Orchestrate one user action: find, authorize, compose | `success`/`failure(errors:)` | [[authoring-user-stories]] |
| Use case | One transactional unit of work | `success`/`failure` | [[authoring-use-cases]] |
| Form object | Validate params; build domain objects | `valid?` + built objects | [[authoring-form-objects]] |
| Query object | Scoped, composable reads | a relation / chainable query | [[authoring-query-objects]] |
| Model | Data shape, integrity, intrinsic accessors | data | [[authoring-models]] |
| Serializer | Present data as JSON:API | response hash | [[authoring-serializers]] |


## Decision Guide

- A whole user action (find → authorize → do → respond)? → **user story**.
- One transactional write, reusable, no orchestration? → **use case**.
- Validating params and constructing objects to persist? → **form object**.
- A read with scoping/joins reused across callers? → **query object**.
- Data integrity / a tiny pure accessor? → **model**.
- Shaping a response? → **serializer**.


## Collaboration (write path)

```
controller / graphql endpoint        (delivery adapter; is the listener)
        │  builds a Form, calls a User Story / Use Case with listener: self
        ▼
user story                           (orchestration: find, authorize, compose)
        │  uses a Form to validate+build, delegates the write to a Use Case
        ▼
use case                             (transactional write) ──► success/failure
        ▲
form object   (validate + build)     model   (persist)      query object (reads)
```

The adapter passes `listener: self, on_success:, on_failure:`; the story/use case calls back;
the adapter renders via a serializer. No layer below the adapter knows about HTTP/GraphQL.


## Placement (summary — see references/directory-map.md)

```
app/lib/user_stories/graph/<domain>/<action>.rb  UserStories::Graph::<Domain>::<Action>
app/lib/use_cases/<domain>/<action>.rb           UseCases::<Domain>::<Action>
app/lib/forms/<domain>/<action>_form.rb           Forms::<Domain>::<Action>Form
app/lib/queries/<scope>/<name>_query.rb           Queries::<Scope>::<Name>Query
app/models/<model>.rb                             <Model>
apis/v1/app/controllers/v1/<resource>_controller.rb
apis/v1/app/serializers/v1/<resource>_serializer.rb
apis/graph/app/graphql/graph/{mutations,resolvers,types}/...
```

Engines and API engines carry their own `app/lib/...` and base classes.
