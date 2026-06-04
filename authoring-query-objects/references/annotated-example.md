# common_agent_skills/derisk_layers/authoring-query-objects/references/annotated-example.md


# Annotated Example — Query Object

Neutral domain: `Queries::IdentityScoped::ArticlesQuery` — articles visible to an identity.
The companion spec is the annotated example in [[testing-query-objects]].

```ruby
# frozen_string_literal: true

module Queries
  module IdentityScoped
    class ArticlesQuery < ApplicationQuery
      # The default relation: ApplicationQuery resolves Article as the base.
      relation_class 'Article'

      # The scope object whose boundary this query enforces.
      attr_reader :identity

      def initialize(identity, **)
        @identity = identity
        # Pass no explicit relation; the base uses relation_class. Forward kwargs.
        super(nil, **)
      end

      # A custom refiner — the core contract: mutate @relation, return self,
      # so callers can keep chaining.
      def with_status(status)
        @relation = relation.where(status: status)
        self
      end


      private

      # Called by ApplicationQuery#initialize. Build the scoped, eager-loaded relation here.
      def build_relation_defaults!
        @relation = relation
                    .includes(:author)                 # avoid N+1
                    .where(author_id: identity.id)     # the boundary
                    .where(archived_at: nil)           # default condition
                    .distinct
      end
    end
  end
end

# Usage — refiners chain, one terminator ends the chain:
#   ArticlesQuery.new(current_identity)
#     .with_status('published')
#     .order(sort_field: :created_at, sort_direction: :desc)
#     .page(1).per(20)
#     .all
```


## Why these choices

- **`relation_class 'Article'`** declares the base model so the object knows what it
  queries without the caller passing a relation.
- **Scope in the constructor.** Taking `identity` and calling `super(nil, **)` keeps the
  boundary object explicit and forwards options (e.g. `relation:`) to the base.
- **`build_relation_defaults!` is the single place the scope is applied.** Callers get a
  relation already constrained to what the identity may see — they cannot widen it.
- **The refiner honours the core contract.** `with_status` mutates `@relation` and returns
  `self`; a refiner returning a relation mid-chain breaks composability.
- **`includes` up front** prevents N+1s for the associations the caller will render.
- **`distinct`** because joins can fan out rows.
- **Composable tail.** `order`/`page`/`per`/`all` come from the base, so the call site reads
  like a fluent query without leaking the scoping concern.
