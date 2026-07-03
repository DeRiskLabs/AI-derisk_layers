# Authoring Checklist — Engines

## Decision
- [ ] The slice genuinely needs Rails abstractions (else: a component).
- [ ] Family chosen: feature slice → `engines/<name>/`; collection of API endpoints →
      `apis/<name>/`.

## Shell
- [ ] Mountable engine (`isolate_namespace <Name>` in `engine.rb`).
- [ ] Standalone spec home generated and kept: own `Gemfile`, `.rspec`,
      `spec_helper`/`rails_helper`, and a schema-less `spec/dummy` app — do not prune them.
- [ ] gemspec declares `rails` plus every Rails-facing dependency the engine owns.
- [ ] `engine.rb` stance matches the family: session-middleware dedup (feature) or
      `api_only` + null session + JSON default (API).
- [ ] Consumed via the container Gemfile `path` block; mounted in the container's
      routes (feature at `/` with an internal `scope`; API at its protocol path).

## Namespaces
- [ ] Rails-facing classes under the engine constant (`<Name>::ProfilesController`).
- [ ] Layer objects in the app-wide families with an engine sub-namespace
      (`UseCases::<Name>::...`, `UserStories::<Name>::...`, `Forms::<Name>::...`).
- [ ] Engine-local bases exist and stay behavioural:
      `UseCases::<Name>::BaseUseCase < Layers::BaseLayer`,
      `UserStories::<Name>::BaseUserStory < Layers::BaseLayer`,
      `<Name>::ApplicationController`.

## Boundaries
- [ ] No engine-local models or migrations — the container owns persistence.
- [ ] API engines own their user stories (`apis/<name>/app/lib/user_stories/<name>/`).
- [ ] Controllers/jobs/mailers thin: translate, delegate, render the callback outcome.
- [ ] Other contexts addressed only through their public interfaces.

## Verify
- [ ] The engine owns a standalone suite: own `Gemfile`/bundle, `.rspec`,
      `spec_helper`/`rails_helper`, and a schema-less `spec/dummy` app (no models, no
      migrations, no database).
- [ ] Specs live in the engine, mirroring its code (`engines/<name>/spec/use_cases/`,
      `spec/requests/`, `spec/features/`), and boot the engine's own `rails_helper`
      (which loads the dummy).
- [ ] Scoped run green from the engine's own directory:
      `cd engines/<name> && bundle exec rspec`.
- [ ] `bin/test_suite` runs each slice in its own directory with its own bundle — the
      container plus every `components/*`, `engines/*`, `apis/*`.
- [ ] Engine specs fake the injected registries and stub auth; the real crossings are
      proven by the container's acceptance specs (see the layered testing doctrine).
- [ ] Request/feature specs cover the mounted routes against the dummy; layer specs
      follow their testing skills.
- [ ] No spec reaches into another context's internals — boundary changes are
      requested from the owning context and tested there.
