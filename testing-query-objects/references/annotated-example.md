# common_agent_skills/derisk_layers/testing-query-objects/references/annotated-example.md


# Annotated Example — Query Object Spec

Neutral domain: `Queries::IdentityScoped::ArticlesQuery` — articles visible to an identity.


## The Object Under Test

The query being specced, compact — the fully annotated version is the annotated example in
[[authoring-query-objects]]:

```ruby
# frozen_string_literal: true

module Queries
  module IdentityScoped
    class ArticlesQuery < ApplicationQuery
      relation_class 'Article'

      attr_reader :identity

      def initialize(identity, **)
        @identity = identity
        super(nil, **)
      end

      def with_status(status)
        @relation = relation.where(status: status)
        self
      end


      private

      def build_relation_defaults!
        @relation = relation
                    .includes(:author)
                    .where(author_id: identity.id)
                    .where(archived_at: nil)
                    .distinct
      end
    end
  end
end
```


## The Spec

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::IdentityScoped::ArticlesQuery do
  # Construct with the scope object — the boundary the spec proves.
  subject(:query) { described_class.new(identity) }

  let(:identity) { FactoryBot.create(:identity) }


  describe '#all' do
    # The scoping boundary: one record on each side. contain_exactly proves
    # inclusion AND exclusion with one assertion.
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

    # The empty case: in-scope nothing, out-of-scope something.
    context 'when the identity has no articles' do
      before { FactoryBot.create(:article, author: FactoryBot.create(:identity)) }

      execute(:results) do
        query.all
      end

      it 'returns no articles' do
        expect(results).to be_empty
      end
    end

    # Each composed condition gets a context with a record failing exactly that
    # condition — here the archived filter.
    context 'when an in-scope article is archived' do
      let!(:live_article) { FactoryBot.create(:article, author: identity) }

      before { FactoryBot.create(:article, :archived, author: identity) }

      execute(:results) do
        query.all
      end

      it 'excludes the archived article' do
        expect(results).to contain_exactly(live_article)
      end
    end
  end


  describe '#order' do
    let!(:older_article) { FactoryBot.create(:article, author: identity, created_at: 2.days.ago) }
    let!(:newer_article) { FactoryBot.create(:article, author: identity, created_at: 1.day.ago) }

    execute(:results) do
      query.order(sort_field: :created_at, sort_direction: :desc).all
    end

    it 'returns the newest article first' do
      expect(results.first).to eq(newer_article)
    end
  end


  describe '#page' do
    before do
      FactoryBot.create_list(:article, 3, author: identity)
    end

    execute(:results) do
      query.page(1).per(2).all
    end

    it 'limits the page to the per size' do
      expect(results.size).to eq(2)
    end
  end


  describe '#per' do
    # Raising contract → block expectation (the raising-action exception).
    context 'when called before #page' do
      it 'raises PaginationError' do
        expect do
          query.per(10)
        end.to raise_error(Queries::Concerns::Paginatable::PaginationError)
      end
    end
  end


  describe '#with_status' do
    # The refiner contract, both halves. A null-object spy passes the base's
    # duck-type check, absorbs the defaults chain, and records messages.
    subject(:query) { described_class.new(identity, relation: relation) }

    let(:relation) { spy('relation') }

    execute(:chained) do
      query.with_status('published')
    end

    # Identity half: same object back, so the chain continues.
    it 'returns the query for further chaining' do
      expect(chained).to be(query)
    end

    # Mutation half: the relation received the intended message.
    it 'narrows the relation to the status' do
      expect(relation).to have_received(:where).with(status: 'published')
    end
  end
end
```


## Why these choices

- **Test at the boundary.** The spec proves what callers receive — records in, records
  out — never how `build_relation_defaults!` assembles the relation. The SQL is free to
  change; the boundary is not.
- **Real database, deliberately.** A query's behaviour IS its SQL against real rows; a
  doubled relation proves nothing. This is one of the necessary slow tests.
- **`contain_exactly` for the scope.** Inclusion of the in-scope record and exclusion of
  the out-of-scope record in one assertion — the strongest single statement of the
  boundary.
- **One context per composed condition.** Each `where`/`join` earns a record that fails
  exactly that condition, so a regression in any branch fails exactly one context.
- **`execute(:results)`.** The query call is the action under test; the named let keeps
  examples reading as assertions on the result (incoming query → assert the return value).
- **The raising contract via block expectation** — `per` before `page` is part of the
  public interface and gets pinned like any other behaviour.
- **Refiners prove both halves of their contract.** Identity (`be(query)` — the chain
  continues) and mutation (the relation spy received the intended message). The DB-backed
  contexts prove behaviour; the spy proves the contract; together a refiner cannot chain
  but filter wrongly, nor filter but break the chain, undetected.
