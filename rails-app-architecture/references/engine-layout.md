# common_agent_skills/derisk_layers/rails-app-architecture/references/engine-layout.md


# Engine Layout — The Modular Monolith

How the codebase is split, and how to add to it.


## Top-level shape

```
app/                  main app: user_stories (incl. graph/), lib/{use_cases,queries,forms},
                      models, validators
apis/
  v1/                 REST/JSON:API engine: controllers, serializers, lib/{use_cases,forms}, jobs
  graph/              GraphQL engine: graphql/{types,mutations,resolvers}
engines/
  auth/               feature engine: controllers, views, jobs, mailers, lib/...
  collab/             feature engine
  info_vault/         feature engine
```

- **API engines (`apis/*`)** are delivery boundaries. They expose the app over a protocol
  (REST, GraphQL) and own protocol-specific concerns: serializers, types, error formatting,
  authentication wiring. They may contain protocol-specific forms (e.g.
  `Forms::V1::ProfileUpdate`); graph-facing **user stories live in the main app**
  (`app/user_stories/graph/...`) — the engine declares them by name and only the thin
  `UserStories::Graph::Base` may live engine-side.
- **Feature engines (`engines/*`)** own a bounded slice of the domain (auth, collaboration,
  info vault): their controllers/views/jobs/mailers and their own `app/lib/...` layer objects.
- The **main app** holds shared domain: models, cross-cutting user stories, use cases,
  queries, and forms not owned by a single engine.


## Base classes per boundary

Each engine/boundary defines a thin base over the `layers` gem so its objects share defaults:

```
UseCases::ApplicationUseCase        < Layers::BaseLayer     (main app use cases)
UserStories::Graph::Base            < Layers::BaseLayer     (+ ActiveModel::Validations)
<Engine>::BaseUserStory             < Layers::BaseLayer     (feature-engine user stories)
Queries::ApplicationQuery                                   (query objects; uses Paginatable)
V1::ApplicationController           < ActionController::Base (+ ErrorHandling, Authorization)
V1::BaseSerializer                  (include JSONAPI::Serializer)
Graph::Mutations::ApplicationMutation / Graph::Resolvers::ApplicationResolver
                                    (include Layers::Graphql::BaseEndpoint)
```


## Adding an endpoint (checklist)

1. Decide the boundary: which engine owns this? (REST → `apis/v1`; GraphQL → `apis/graph`;
   domain feature → the relevant `engines/*`; shared → main app.)
2. Write/extend the **layer objects** first (form, use case or user story, query) in their
   homes — user stories under `app/user_stories/...`, the rest under the boundary's
   `app/lib/...` — each over the boundary's base class. Test them.
3. Add the **delivery adapter** (controller action or GraphQL mutation/resolver) that builds
   the form and calls the user story / use case as listener.
4. Add the **serializer / type** for the response.
5. Add the **route** and a request/acceptance + routing spec.


## The layers gem

All layer base classes inherit from the `layers` gem (`Layers::BaseLayer`,
`Layers::BaseQueryObject`, `Layers::Graphql::BaseEndpoint`). Consume it via the Gemfile —
a private git source in applications (`gem 'layers', git: ...`), or a `path` source while
developing the gem itself.
