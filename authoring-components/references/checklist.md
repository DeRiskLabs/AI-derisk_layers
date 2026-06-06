# Authoring Checklist — Components

## Decision
- [ ] The slice is pure domain logic — no controllers, views, jobs, mailers, or GraphQL
      types needed (those make it an engine, under `engines/` — or `apis/` if it is a
      collection of API endpoints).
- [ ] No models or migrations of its own — persistence stays in the container.
- [ ] It is not a generic extractable library (those live in `lib/`).

## Skeleton
- [ ] Generated with `bin/rails generate layers:component <name>` (or matches its
      output — see `annotated-skeleton.md`) under `components/<name>/`.
- [ ] Consumed via the application Gemfile: `path 'components' do gem '<name>' end`.
- [ ] Every file explicitly required from the root file (or a file it requires).

## Public interface
- [ ] Entry only through class methods on the root constant, each wrapping a use case.
- [ ] Outcomes leave through listener callbacks (`success`/`failure`), never as
      interrogated return values.
- [ ] Public method count stays small; growing collections are grouped into modules
      mixed into the root constant — or the context is split.
- [ ] Internal layer objects inherit a component-local base
      (`<Name>::BaseUseCase < Layers::BaseLayer`).

## Configuration
- [ ] Settings with defaults are `attr_writer` + a memoized reader carrying the
      default; `attr_accessor` only for nil-default flags.
- [ ] Environment-driven defaults sit in private `detect_*` methods.
- [ ] The root constant carries the memoized `configuration` / yielding `configure`
      pair.

## Registry
- [ ] Host classes resolved via `<Name>.configuration.repo[:key]`; no host constants
      named anywhere in the component.
- [ ] The container fills the registry in a boot initializer through the component's
      configure block.
- [ ] Nothing memoizes a resolved constant.

## Boundaries
- [ ] gemspec depends on `layers` (and pure-Ruby gems only), never `rails`.
- [ ] Other contexts addressed only through their root-constant public interfaces.
- [ ] No user stories inside the component; no use case calls one.

## Verify
- [ ] Isolated suite green: `bin/test_components` from the app root (or
      `BUNDLE_GEMFILE=Gemfile bundle exec rspec` in the component).
- [ ] Specs swap the whole registry (`configuration.repo = { ... }`) instead of
      registering doubles.
