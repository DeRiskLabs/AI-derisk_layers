---
name: testing-graphql
title: Testing GraphQL Acceptance Specs
description: Spec pattern for GraphQL acceptance specs that post a query or mutation to /graphql and assert on the parsed JSON data and errors. The ONLY spec layer for GraphQL - mutations, resolvers, and types get no unit specs. Use when writing or modifying specs under spec/acceptance/graph.
category: testing
status: active
version: 1.1
applies_to:
  - Ruby
  - Rails
  - RSpec
  - GraphQL
  - always_execute
priority: REQUIRED
triggers:
  - graphql spec
  - graphql mutation spec
  - graphql query spec
  - acceptance graph spec
  - assert response_data errors
anti_triggers:
  - plain request spec
  - use case spec
  - model spec
user_invocable: true
last_reviewed_at: 2026-06-03
---


# Testing GraphQL Acceptance Specs

Use this skill for end-to-end GraphQL specs that post a document to `/graphql` and assert on
the parsed response. These exercise the full stack: schema → mutation/resolver →
`Layers::Graphql::BaseEndpoint` → user story.


## Scope: Acceptance Only

This is the **only** spec layer for GraphQL. Mutations, resolvers, and types are pure
declarations ([[authoring-graphql-mutations]], [[authoring-graphql-queries]]) — do NOT
write unit specs for them. The division of labour:

- **Acceptance specs (this skill)** — the declaration and its wiring, end to end.
- **User story specs** ([[testing-user-stories]]) — the behaviour, unit-tested.
- **The layers gem's own suite** ([[testing-layers-base-classes]]) — `Layers::Graphql::BaseEndpoint`
  and the DSL mixins, tested exhaustively once.


## Required Reading

```text
common_agent_skills/derisk_ruby/ruby-testing/SKILL.md
common_agent_skills/derisk_ruby/always-execute-rspec/SKILL.md
common_agent_skills/derisk_rails/testing-rails-requests/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-mutation.md   # a full mutation acceptance spec, annotated
references/annotated-query.md      # a full query acceptance spec, annotated
references/checklist.md            # pre-merge review checklist
```


## Shape

- `RSpec.describe 'GraphQL Mutation: createX', type: %i[request acceptance]` — the
  `%i[request acceptance]` types are what mix in `GraphQLResponseHelpers`
  (`parsed_response`, `response_data`, `response_errors`).
- `let(:query)` holds the GraphQL document as a heredoc/`%()` string.
- `let(:variables)` holds the variables as a JSON string (interpolate `let`s).
- `let(:params) { { query: query, variables: variables } }`.
- The action is `post '/graphql', params: params.to_json, headers: headers` in `execute`.
- Pull the interesting parts of the response into `let`s with `dig`, defaulting safely.

```ruby
let(:response_data) { JSON.parse(response.body)['data'] }
let(:article_data) { response_data&.dig('createArticle', 'article') }
let(:article_errors) { response_data&.dig('createArticle', 'errors') || [] }
```


## Authentication

```ruby
context 'with an authenticated user' do
  include_context 'with api authentication'
  let(:headers) { graphql_authenticated_headers }

  it_behaves_like 'requires authentication'
  # ... authenticated_identity is available here
end
```


## What to Assert

One expectation per `it`, against the parsed response:

- field values: `expect(article_data['title']).to eq(title)`
- status / shape: `expect(article_data['status']).to eq('draft')`
- no errors on success: `expect(article_errors).to be_empty`
- error message and path on failure:
  ```ruby
  it 'returns the expected error message' do
    expect(article_errors.first['message']).to eq("title: can't be blank")
  end

  it 'returns the expected error path' do
    expect(article_errors.first['path']).to eq(['createArticle', 'Article', 'title'])
  end
  ```


## Record-Count Changes

Use a block matcher and post inside the expectation:

```ruby
it 'creates a new article record' do
  expect { post '/graphql', params: params.to_json, headers: headers }
    .to change(Article, :count).by(1)
end

it 'does not create an article' do
  expect { post '/graphql', params: params.to_json, headers: headers }
    .not_to change(Article, :count)
end
```


## Queries vs Mutations

Both use the identical shape (`type: %i[request acceptance]`, `query`/`params`, `post
'/graphql'`). Differences in practice:

- **Mutations** assert field-by-field on the mutation payload and on `errors` (message/path);
  use `change(Model, :count)` block matchers for persistence.
- **Queries** typically build fixtures with `let!`, then assert the **whole** shape with one
  `expect(response_data).to eq(expected_response)` plus `expect(response_errors).to be_empty`.
  Cover the empty case (`'articles' => []`) and the scoping case (other users' records
  excluded).

```ruby
let!(:article) { FactoryBot.create(:article, author: authenticated_identity) }

it 'returns the expected response data' do
  expect(response_data).to eq(expected_response)
end
```


## Avoid

- multiple expectations per `it`; the `post` inside an `it` except for block matchers.
- asserting on the full response hash when one field/error is the behaviour under test
  (a single `eq(expected_response)` is acceptable when the whole shape is the point — common
  for queries).
- unit specs for mutations, resolvers, or types — this layer is acceptance only.


## Preferred Structure

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GraphQL Mutation: createArticle', type: %i[request acceptance] do
  let(:query) do
    %(
      mutation createArticle($title: String!) {
        createArticle(title: $title) {
          article { id title status }
          errors { message path }
        }
      }
    )
  end
  let(:variables) { %({ "title": "#{title}" }) }
  let(:params) { { query: query, variables: variables } }
  let(:headers) { {} }

  let(:response_data) { JSON.parse(response.body)['data'] }
  let(:article_data) { response_data&.dig('createArticle', 'article') }
  let(:article_errors) { response_data&.dig('createArticle', 'errors') || [] }

  execute do
    post '/graphql', params: params.to_json, headers: headers
  end

  context 'with an authenticated user' do
    include_context 'with api authentication'
    let(:headers) { graphql_authenticated_headers }

    context 'with a valid title' do
      let(:title) { 'Hello World' }

      it 'has the expected title' do
        expect(article_data['title']).to eq(title)
      end

      it 'has no errors' do
        expect(article_errors).to be_empty
      end
    end
  end
end
```
