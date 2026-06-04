# common_agent_skills/derisk_layers/layered-architecture-placement/references/directory-map.md


# Directory Map — Where Each Abstraction Lives

Concrete placement and naming for every layer abstraction. Engines and API engines mirror this
under their own roots and define their own base classes.

## Main app

```
app/
  lib/
    user_stories/
      graph/<domain>/<action>.rb      UserStories::Graph::<Domain>::<Action>   (< UserStories::Graph::Base)
    use_cases/
      application_use_case.rb         UseCases::ApplicationUseCase             (< Layers::BaseLayer)
      <domain>/<action>.rb            UseCases::<Domain>::<Action>             (< ApplicationUseCase)
    queries/
      application_query.rb            Queries::ApplicationQuery
      concerns/paginatable.rb         Queries::Concerns::Paginatable
      <scope>/<name>_query.rb         Queries::<Scope>::<Name>Query            (< ApplicationQuery)
    forms/
      <domain>/<action>_form.rb       Forms::<Domain>::<Action>Form            (ActiveModel::Model)
  models/
    <model>.rb                        <Model>                                  (< ApplicationRecord)
    concerns/<name>.rb                shared model behaviour
  validators/<name>_validator.rb      custom ActiveModel validators
```

## REST API engine (apis/v1)

```
apis/v1/app/
  controllers/
    v1/application_controller.rb      V1::ApplicationController
    v1/<resource>_controller.rb       V1::<Resource>Controller
    concerns/v1/{error_handling,authorization}.rb
  serializers/v1/
    base_serializer.rb                V1::BaseSerializer                       (JSONAPI::Serializer)
    <resource>_serializer.rb          V1::<Resource>Serializer                 (< BaseSerializer)
  lib/{use_cases,forms}/...           engine-local layer objects (e.g. Forms::V1::ProfileUpdate)
```

## GraphQL API engine (apis/graph)

```
apis/graph/app/graphql/graph/
  mutations/application_mutation.rb   Graph::Mutations::ApplicationMutation    (include Layers::Graphql::BaseEndpoint)
  mutations/<action>.rb               Graph::Mutations::<Action>
  resolvers/application_resolver.rb   Graph::Resolvers::ApplicationResolver    (include Layers::Graphql::BaseEndpoint)
  resolvers/<name>.rb                 Graph::Resolvers::<Name>
  types/base/*.rb                     Graph::Types::Base::{Object,Field,...}
  types/<domain>/<name>_type.rb       domain types
```

Graph-facing user stories live in the MAIN app (`app/lib/user_stories/graph/...`), not inside
the engine — the engine declares them by name (`user_story 'user_stories/graph/...'`) and
the behaviour stays in the app's domain layer. Only the thin `UserStories::Graph::Base`
may live engine-side.

```
```

## Feature engines (engines/<engine>)

```
engines/<engine>/app/
  controllers/, views/, jobs/, mailers/
  lib/user_stories/<engine>/base_user_story.rb   <Engine>::BaseUserStory       (< Layers::BaseLayer)
  lib/{use_cases,forms,queries}/...
```

## Rule of thumb

Cross-cutting/domain logic for the main app goes under `app/lib/<type>/<domain>/` — user
stories included. Anything specific to an API or feature boundary lives in that engine's
mirror of this structure, with an engine-local base class over the gem's base.

Never invent new top-level `app/<abstraction>/` directories for your own abstractions:
Zeitwerk roots every `app/*` subdirectory WITHOUT a namespace, so `app/user_stories/...`
files would define un-namespaced constants (or need custom autoloader wiring). Under
`app/lib/` the directory structure yields the namespace for free
(`app/lib/user_stories/graph/foo.rb` → `UserStories::Graph::Foo`).
