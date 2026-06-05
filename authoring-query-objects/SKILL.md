---
name: authoring-query-objects
title: Authoring Query Objects
description: How to write a query object - a class that encapsulates a scoped, composable ActiveRecord query behind a small interface. Use when adding or changing classes under app/lib/queries.
category: architecture
status: active
version: 1.2
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
last_reviewed_at: 2026-06-04
---


# Authoring Query Objects

A query object encapsulates a **scoped, composable read** of an ActiveRecord model behind a
small interface, so controllers/user stories never assemble joins and conditions inline.


## Required Reading

```text
common_agent_skills/derisk_layers/layered-architecture-placement/SKILL.md
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

Scopes group queries by the boundary they enforce, e.g. `IdentityScoped`, `FirmScoped`. A
base `ApplicationQuery` sits at `app/lib/queries/application_query.rb`. (`ApplicationQuery` is
the app's richer evolution of the gem's `Layers::BaseQueryObject` — same shape: a default
relation class, delegated AR methods, an `order`, and a `Paginatable` concern.)


## The Core Contract: Chainable

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

Query objects are real logic objects — the reads extracted from models so models stay
thin — and every one gets its own spec. Test with [[testing-query-objects]]: DB-backed
boundary specs covering the scoping boundary, the empty case, each composed condition,
and the chainable interface.

The consuming endpoints' request/acceptance specs still cover their own scoping and empty
cases — that exercises the wiring, not a substitute for the query's spec.


## Rules

- A query object is **read-only**. No writes, no side effects.
- The scope (tenant, identity, firm) is enforced in `build_relation_defaults!` so callers
  cannot accidentally cross the boundary.
- Honour the core contract: refining methods return `self`; only terminators return
  collections/records.
- Keep SQL fragments in small private methods (one per join/condition) when they grow.


## Avoid

- business logic or writes — those belong in use cases / user stories.
- exposing the raw relation so callers re-scope around the boundary.
- N+1s — declare `includes` for what the caller will read.
- leaving a growing pile of model scopes that should have become a query object.
