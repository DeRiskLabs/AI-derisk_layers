# Engine Layout — The Modular Monolith

How the codebase is split, and how to add to it.


## Top-level shape

```
app/                  main app: lib/{use_cases,queries,forms}, models, validators
apis/
  v1/                 REST/JSON:API engine: controllers, serializers, lib/{use_cases,forms}, jobs
  graph/              GraphQL engine: graphql/{types,mutations,resolvers}, lib/user_stories/graph
engines/
  auth/               feature engine: controllers, views, jobs, mailers, lib/...
  collab/             feature engine
  info_vault/         feature engine
components/
  accounts/           pure-domain bounded context (unbuilt gem, no Rails inside)
lib/                  generic libraries that could be extracted entirely (+ tasks, assets)
```

- **API engines (`apis/*`)** are delivery boundaries. They expose the app over a protocol
  (REST, GraphQL) and own protocol-specific concerns: serializers, types, error formatting,
  authentication wiring — and **their own user stories**: graph-facing user stories are
  boundaries of the graph API, so they live inside the engine
  (`apis/graph/app/lib/user_stories/graph/...`). The endpoint declares them by name
  (`user_story 'user_stories/graph/...'`); the engine's `app/lib` is an autoload root, so
  the `UserStories::Graph::*` constants are unchanged. Protocol-specific forms (e.g.
  `Forms::V1::ProfileUpdate`) live engine-side too.
- **Feature engines (`engines/*`)** own a bounded slice of the domain (auth, collaboration,
  info vault): their controllers/views/jobs/mailers and their own `app/lib/...` layer objects.
- **Components (`components/*`)** are pure-domain bounded contexts packaged as unbuilt
  gems: no Rails abstractions, a root-constant public interface, persistence through a
  boot-filled repository registry — see the authoring-components skill.
- The **main app** holds all models, plus shared domain not owned by a single engine:
  use cases, queries, forms, and any user stories the main app itself owns.
- `apis/`, `engines/`, and `components/` are each consumed through Gemfile
  `path '<location>' do ... end` blocks; nothing in them is autoloaded by the container.


## Base classes per boundary

Each engine/boundary defines a thin base over the `layers` gem so its objects share defaults:

```
UseCases::ApplicationUseCase        < Layers::BaseLayer     (main app use cases)
UserStories::Graph::Base            < Layers::BaseLayer     (graph-engine user stories; + ActiveModel::Validations)
UserStories::<Engine>::BaseUserStory < Layers::BaseLayer    (feature-engine user stories)
UseCases::<Engine>::BaseUseCase     < Layers::BaseLayer     (feature-engine use cases)
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
   homes under the boundary's `app/lib/...` (user stories included) — each over the
   boundary's base class. Test them.
3. Add the **delivery adapter** (controller action or GraphQL mutation/resolver) that builds
   the form and calls the user story / use case as listener.
4. Add the **serializer / type** for the response.
5. Add the **route** and a request/acceptance + routing spec.


## The layers gem

All layer base classes inherit from the `layers` gem (`Layers::BaseLayer`,
`Layers::BaseQueryObject`, `Layers::Graphql::BaseEndpoint`). Consume it via the Gemfile —
a private git source in applications (`gem 'layers', git: ...`), or a `path` source while
developing the gem itself.
