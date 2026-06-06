# Authoring Checklist — Engines

## Decision
- [ ] The slice genuinely needs Rails abstractions (else: a component).
- [ ] Family chosen: feature slice → `engines/<name>/`; collection of API endpoints →
      `apis/<name>/`.

## Shell
- [ ] Mountable engine (`isolate_namespace <Name>` in `engine.rb`).
- [ ] Generated scaffolding pruned: no test directory, no dummy app.
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
- [ ] Specs live in the engine, mirroring its code (`engines/<name>/spec/use_cases/`,
      `spec/requests/`, `spec/features/`); files `require 'rails_helper'` — the
      container's resolves via the load path, no shim.
- [ ] Scoped run green from the app root: `bundle exec rspec engines/<name>/spec`.
- [ ] `bin/test_suite` runs `spec apis/*/spec engines/*/spec` (no slice paths in
      `.rspec` patterns — they break scoped runs).
- [ ] No per-engine dummy app; no engine-local bundle for specs.
- [ ] Request/feature specs cover the mounted routes; layer specs follow their
      testing skills.
- [ ] No spec reaches into another context's internals — boundary changes are
      requested from the owning context and tested there.
