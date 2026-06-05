---
name: testing-query-objects
title: Testing Query Objects
description: Spec pattern for query objects (Queries::*) - DB-backed specs that pin the scoping boundary, the empty case, each composed condition, and the chainable interface. Use when writing or modifying specs under spec/lib/queries.
category: testing
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - RSpec
  - always_execute
  - ActiveRecord
priority: REQUIRED
triggers:
  - query object spec
  - Queries spec
  - scoping boundary spec
  - pagination spec
anti_triggers:
  - model spec
  - use case spec
  - request spec
user_invocable: true
last_reviewed_at: 2026-06-03
---


# Testing Query Objects

Query objects (`Queries::*`) are the reads extracted from models — real logic objects, so
they get real specs. **Test at the boundary**: the spec builds records on both sides of the
scope and asserts what the query returns, never how the relation is assembled.

The reference suite has no query specs — that is drift. Every query object gets one.


## Required Reading

```text
common_agent_skills/derisk_ruby/ruby-testing/SKILL.md
common_agent_skills/derisk_ruby/always-execute-rspec/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # a full query spec, annotated
references/checklist.md           # pre-merge review checklist
```

Authoring the objects under test: [[authoring-query-objects]].


## Shape

- `require 'rails_helper'`; DB-backed (`FactoryBot.create`) — a query's behaviour *is* its
  SQL, so this is a necessary slow test.
- `subject(:query) { described_class.new(identity) }` — construct with the scope object.
- One `describe` per public entry (`#all`, plus chaining behaviours).
- The query call is the action under test: `execute(:results) do query.all end`; examples
  assert on `results`.

```ruby
subject(:query) { described_class.new(identity) }

let(:identity) { FactoryBot.create(:identity) }

describe '#all' do
  let!(:in_scope_article) { FactoryBot.create(:article, author: identity) }

  before { FactoryBot.create(:article, author: FactoryBot.create(:identity)) }

  execute(:results) do
    query.all
  end

  it 'returns only the articles in scope' do
    expect(results).to contain_exactly(in_scope_article)
  end
end
```


## What to Cover

1. **The scoping boundary** — one in-scope and one out-of-scope record;
   `contain_exactly` proves both inclusion AND exclusion in one assertion.
2. **The empty case** — no in-scope records → empty result.
3. **Each composed condition** — every `where`/`join` branch in
   `build_relation_defaults!` gets a context with a record that fails exactly that
   condition.
4. **Every refining method's contract** — both halves, each its own example:
   - it returns the **object under test** (chainability): `expect(query.with_status('published')).to be(query)`
   - it **mutates the relation** as intended — often by stubbing the relation and
     expecting the message
5. **The `per`-before-`page` raise** (block expectation — the raising-action exception).

```ruby
describe '#per' do
  context 'when called before #page' do
    it 'raises PaginationError' do
      expect do
        query.per(10)
      end.to raise_error(Queries::Concerns::Paginatable::PaginationError)
    end
  end
end
```


## Refiners: Identity and Mutation

A refining method has a two-part contract. Pin the **identity** half with `be` (same
object, so the chain continues), and the **mutation** half by injecting a relation spy
through the base's `relation:` option and asserting the message it received:

```ruby
describe '#with_status' do
  subject(:query) { described_class.new(identity, relation: relation) }

  let(:relation) { spy('relation') }   # null object: passes the duck-type check,
                                       # absorbs the defaults chain, records messages

  execute(:chained) do
    query.with_status('published')
  end

  it 'returns the query for further chaining' do
    expect(chained).to be(query)
  end

  it 'narrows the relation to the status' do
    expect(relation).to have_received(:where).with(status: 'published')
  end
end
```

The DB-backed contexts (`#all`, `#order`, `#page`) prove the *behaviour*; the spy proves
the *contract*. Use both: a refiner that chains but filters wrongly fails the behaviour
specs; one that filters but breaks the chain fails the identity spec.


## Avoid

- asserting SQL strings or relation internals — assert returned records (the boundary)
  or messages to the relation (the refiner contract).
- replacing the DB-backed behaviour specs with relation stubs — the spy-based refiner
  contract specs complement them, never substitute for them.
- covering only the happy scope — exclusion and emptiness are the point.
- multiple expectations per `it`; the query call outside `execute` (block-matcher and
  raising exceptions aside).


## Preferred Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::IdentityScoped::ArticlesQuery do
  subject(:query) { described_class.new(identity) }

  let(:identity) { FactoryBot.create(:identity) }


  describe '#all' do
    context 'when the identity has articles' do
      let!(:in_scope_article) { FactoryBot.create(:article, author: identity) }

      before { FactoryBot.create(:article, author: FactoryBot.create(:identity)) }

      execute(:results) do
        query.all
      end

      it 'returns only the articles in scope' do
        expect(results).to contain_exactly(in_scope_article)
      end
    end

    context 'when the identity has no articles' do
      before { FactoryBot.create(:article, author: FactoryBot.create(:identity)) }

      execute(:results) do
        query.all
      end

      it 'returns no articles' do
        expect(results).to be_empty
      end
    end
  end
end
```
