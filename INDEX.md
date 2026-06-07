# derisk_layers

Using the layers gem in a Rails app. Assumes: derisk_common, derisk_ruby, derisk_rails.

## Architecture (read first)

- [[rails-app-architecture]] — topology, request flow, where to start, the pairing rule (the hub).
- [[boundaries-and-context-mapping]] — where bounded-context boundaries go, overgrown/over-fine smells, the context map.
- [[cross-context-communication]] — crossing mechanics: commands (use case + listener) vs queries (side-effect-free returns).
- [[layered-architecture-placement]] — which layer object to write and where it lives.

## Authoring

- [[authoring-components]] — bounded contexts as unbuilt gems in `components/` (root-constant interface, repository registry).
- [[authoring-engines]] — operationally creating feature (`engines/*`) and API (`apis/*`) engines: generation, namespaces, mounting, bases, spec wiring.
- [[authoring-controllers]] — REST/JSON:API controllers (thin; delegate to use cases).
- [[authoring-use-cases]] — single transactional writes (`UseCases::*`).
- [[authoring-user-stories]] — orchestration objects (`UserStories::*`).
- [[authoring-query-objects]] — scoped, composable reads (`Queries::*`).
- [[authoring-graphql]] — GraphQL layer hub: engine anatomy, base classes, types, wiring.
- [[authoring-graphql-mutations]] — declarative mutations via `user_story` / `user_story_arg`.
- [[authoring-graphql-queries]] — declarative query resolvers; scoping in the user story.
- [[authoring-layers-jobs]] — the layers overlay on jobs: Layers::BaseJob, JobFailed retry mapping, fire_and_forget.
- [[authoring-layers-forms]] — the layers overlay on forms: ApplicationForm over Layers::BaseForm; each form writes only accessors, validations, builders, whitelist.
- [[api-authentication-authorization]] — authentication at the engine edge producing the security credential (current_authorization); authorization as credential scoping in user stories.

## Testing

- [[testing-use-cases]] — message-passing use-case specs.
- [[testing-query-objects]] — DB-backed boundary specs for query objects.
- [[testing-user-stories]] — orchestration/user-story specs.
- [[testing-graphql]] — GraphQL acceptance specs (the ONLY GraphQL spec layer).
- [[testing-layers-base-classes]] — the Layers::BaseLayer family: gem base classes, DSL mixins, app base classes.
