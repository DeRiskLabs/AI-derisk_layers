# Directory Map — Where Each Abstraction Lives

Concrete placement and naming for every layer abstraction. Engines and API engines mirror this
under their own roots and define their own base classes.

## Main app

```
app/
  lib/
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
apis/graph/app/
  graphql/graph/
    mutations/application_mutation.rb Graph::Mutations::ApplicationMutation    (include Layers::Graphql::BaseEndpoint)
    mutations/<action>.rb             Graph::Mutations::<Action>
    resolvers/application_resolver.rb Graph::Resolvers::ApplicationResolver    (include Layers::Graphql::BaseEndpoint)
    resolvers/<name>.rb               Graph::Resolvers::<Name>
    types/base/*.rb                   Graph::Types::Base::{Object,Field,...}
    types/<domain>/<name>_type.rb     domain types
  lib/
    user_stories/graph/
      base.rb                         UserStories::Graph::Base                 (< Layers::BaseLayer)
      <domain>/<action>.rb            UserStories::Graph::<Domain>::<Action>   (< UserStories::Graph::Base)
```

Graph-facing user stories are boundaries of the graph API, so they live INSIDE the engine
(`apis/graph/app/lib/user_stories/graph/...`), not in the main app. The engine's `app/lib`
is an autoload root, so the constants are still `UserStories::Graph::<Domain>::<Action>` and
endpoints still declare them as `user_story 'user_stories/graph/...'` — placement changes,
names do not.

## Feature engines (engines/<engine>)

```
engines/<engine>/app/
  controllers/, views/, jobs/, mailers/
  lib/user_stories/<engine>/base_user_story.rb   <Engine>::BaseUserStory       (< Layers::BaseLayer)
  lib/{use_cases,forms,queries}/...
```

## Rule of thumb

A layer object lives in the boundary that owns it, always under that boundary's
`app/lib/<type>/<domain>/`. Cross-cutting/domain logic owned by the main app goes under the
main app's `app/lib/`; anything specific to an API or feature boundary — user stories
included — lives in that engine's mirror of this structure, with an engine-local base class
over the gem's base.

Own abstractions always live under `app/lib/<abstraction>/` — never invent new top-level
`app/<abstraction>/` directories. The rule and its Zeitwerk rationale live in the general
skill:

```text
common_agent_skills/derisk_rails/app-lib-placement/SKILL.md
```

The layers-specific overlay is choosing WHICH boundary's `app/lib`: the one that owns the
abstraction.
