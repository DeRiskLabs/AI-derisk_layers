---
name: authoring-query-objects
title: Authoring Query Objects
description: How to write a query object - either a scoped, composable relation read or a singular object-or-nil read behind a small side-effect-free interface. Use when adding or changing classes under app/lib/queries.
category: authoring
status: active
version: 1.4
applies_to:
  - Ruby
  - Rails
  - ActiveRecord
  - Layers::BaseQueryObject
priority: REQUIRED
triggers:
  - write a query object
  - new query class
  - Queries scope
  - extract a scope
anti_triggers:
  - use case (write)
  - user story
  - form object
user_invocable: true
last_reviewed_at: "2026-10-01"
---


# Authoring Query Objects

A query object encapsulates a side-effect-free application read behind a small interface.
Collection reads commonly wrap a scoped, composable relation. Explicitly singular reads
return the object or `nil` and do not need to pretend their source is a relation.


## Required Reading

```text
[[layered-architecture-placement]]
```

Supporting references in this skill:

```text
references/annotated-example.md   # a full query object, annotated
references/checklist.md           # authoring checklist
```


## Placement and Naming

```text
app/lib/queries/<scope>/<name>_query.rb  →  Queries::<Scope>::<Name>Query
```

Scopes group relation queries by the boundary they enforce, e.g. `IdentityScoped`,
`FirmScoped`. A relation query inherits the app's `ApplicationQuery` over
`Layers::BaseQueryObject`. A singular object query can be a small PORO when relation,
ordering, and pagination behavior would be false abstractions.

Scaffold the object + spec pair with `bin/rails generate layers:query_object <name>` —
never hand-create files a generator scaffolds. The current generator emits a relation
query shell. For a singular object query, retain the generated path/spec pair and replace
the relation-specific inheritance and TODOs with the singular protocol below. The
generator should eventually offer this shape directly.


## Relation Query Contract: Chainable

Every public method is one of two kinds:

- **Refining methods return `self`** — they narrow or shape the wrapped relation
  (`order`, `page`, `per`, and any custom refiner you add) so calls compose and the
  query can be scoped further down the chain.
- **Terminating methods return results** — a collection or a record (`all`, `find`,
  `find_by`, `first`, `last`, `count`, `pluck`, …), delegated to the relation by the base.

A custom refiner follows the same shape — mutate `@relation`, return `self`:

```ruby
def with_status(status)
  @relation = relation.where(status: status)
  self
end
```

A method that returns a relation or array from the middle of the chain breaks
composability; a refiner that forgets `self` breaks every call after it.

Order matters: **refiners first, terminators last**. The delegated AR messages return
relations or values — not the query object — so a `where` mid-chain exits the query
object and everything after it is plain ActiveRecord, not your refiners.


## Anatomy

1. Inherit from `ApplicationQuery`.
2. Set the model with `relation_class 'Model'`.
3. Take the scope object in `initialize` and call `super(nil, **)`:
   ```ruby
   def initialize(identity, **)
     @identity = identity
     super(nil, **)
   end
   ```
4. Build the scoped relation in private `build_relation_defaults!` (called from the base
   initializer) using `includes` / `joins` / `where` / `distinct`.
5. Rely on the base for delegated AR methods (`where`, `find`, `count`, …), `order`, and
   pagination (`page` / `per`).
6. Add custom refiners per the core contract: mutate `@relation`, return `self`.

```ruby
module Queries
  module IdentityScoped
    class ArticlesQuery < ApplicationQuery
      relation_class 'Article'

      attr_reader :identity

      def initialize(identity, **)
        @identity = identity
        super(nil, **)
      end

      # A custom refiner: narrows the relation, returns self for chaining.
      def with_status(status)
        @relation = relation.where(status: status)
        self
      end


      private

      def build_relation_defaults!
        @relation = relation
                    .includes(:author)
                    .where(author_id: identity.id)
                    .distinct
      end
    end
  end
end
```


## Non-ActiveRecord Relations (duck-typed)

A query object does **not** require ActiveRecord. The wrapped relation is whatever the
configured relation adapter accepts. With `Layers::Adapters::Relation::DuckType` (set in an
initializer: `Layers.configure { |c| c.relation_adapter = Layers::Adapters::Relation::DuckType }`)
any object answering `#where` is a valid relation, so a query can wrap a non-AR source —
e.g. an in-memory collection of file-backed artifacts — while keeping the same chainable
contract: refiners return `self`, terminators (`all`, `find_by`, `count`, …) delegate to
the relation. Such a subclass builds its relation in `initialize` / `build_relation_defaults!`
(passing it to `super`) rather than naming a model via `relation_class`.

The relation object itself just implements the messages the query uses (`where`, `order`,
and the terminators), over whatever backing store it likes. Reads that need presentation
shaping afterwards belong in a **view model**, not the query (see
[[layered-architecture-placement]]).


## Singular Object Queries

An explicitly singular question returns its object or `nil` through one query message,
normally `#call`. Inject the state-holding collaborator so the query is fast and
independently testable. A container-owned default may be resolved behind a private seam
when delivery registries need to construct the query without knowing container state.

```ruby
module Queries
  class CurrentReleaseQuery
    def initialize(current_release: nil)
      @current_release = current_release || configured_current_release
    end

    def call
      current_release.release
    end


    private

    attr_reader :current_release

    def configured_current_release
      Rails.application.config.x.application.current_release
    end
  end
end
```

Do not wrap one retained object in a one-element collection or fake relation merely to
inherit `ApplicationQuery`. Do not add refiners, pagination, or relation delegation to a
question that has none.


## When to Extract One

A model may carry a few simple scopes ([[authoring-models]]); the moment scopes multiply,
take parameters, or grow joins/SQL, that read belongs here. The query object is the home
for any read a controller or user story would otherwise assemble inline.


## Call Sites

Refiners chain; one terminator ends the chain:

```ruby
Queries::IdentityScoped::ArticlesQuery.new(current_identity)
  .with_status('published')
  .order(sort_field: :created_at, sort_direction: :desc)
  .page(params[:page])
  .per(20)
  .all
```

`per` requires `page` to have been called first (`PaginationError` otherwise).


## Testing Strategy

Query objects are real logic objects and every one gets its own spec. Test relation
queries with DB-backed boundary specs covering scoping, emptiness, composed conditions,
and chaining. Test singular object queries as fast units with an injected collaborator,
asserting the returned object by identity or `nil`. See [[testing-query-objects]].

The consuming endpoints' request/acceptance specs still cover their own scoping and empty
cases — that exercises the wiring, not a substitute for the query's spec.


## Rules

- A query object is **read-only**. No writes, no side effects.
- Relation queries enforce their scope in `build_relation_defaults!` so callers cannot
  accidentally cross the boundary.
- Relation refiners return `self`; only terminators return collections or records.
- Singular queries return the object or `nil` directly and expose no relation API.
- Keep SQL fragments in small private methods when relation conditions grow.


## Avoid

- business logic or writes — those belong in use cases / user stories.
- exposing the raw relation so callers re-scope around the boundary.
- N+1s — declare `includes` for what the caller will read.
- leaving a growing pile of model scopes that should have become a query object.
