# Annotated Example — GraphQL Query Acceptance Spec

Neutral domain: an `articles` list query. Queries differ from mutations: build fixtures with
`let!`, then assert the **whole** response shape.


## The Object Under Test

The resolver being exercised, compact — a pure declaration (fully annotated in
[[authoring-graphql-queries]]). Scoping lives in the user story it runs, which is what the
spec's scoping case exercises.

```ruby
module Graph
  module Resolvers
    module Articles
      class Articles < Graph::Resolvers::ApplicationResolver
        description 'Fetches articles the current user has access to'

        type [Types::Articles::Type], null: false

        user_story 'user_stories/graph/articles/fetch_all'
        user_story_arg :current_authorization

        def on_success(articles: nil)
          articles
        end

        def on_failure(articles: nil, errors: nil)
          errors_list = Array(articles ? articles.errors : errors)
          errors_list.map do |error|
            GraphQL::ExecutionError.new(error.message)
          end
        end
      end
    end
  end
end
```


## The Spec

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GraphQL Query: articles', type: %i[request acceptance] do
  describe 'A valid GraphQL request' do
    let(:query) do
      %(
        query getArticles {
          articles { id title status }
        }
      )
    end
    let(:params)  { { query: query } }
    let(:headers) { {} }

    let(:response_data) { JSON.parse(response.body)['data'] }

    execute do
      post '/graphql', params: params.to_json, headers: headers
    end

    context 'with an authenticated user' do
      include_context 'with api authentication'
      let(:headers) { graphql_authenticated_headers }

      context 'when the user has articles' do
        # let! so the records exist before the query runs in execute.
        let!(:article) do
          FactoryBot.create(:article, title: 'First', author: authenticated_user)
        end

        let(:expected_response) do
          {
            'articles' => [
              { 'id' => article.uuid, 'title' => 'First', 'status' => 'draft' },
            ],
          }
        end

        it_behaves_like 'requires authentication'

        # Whole-shape assertion: for read queries the entire payload IS the behaviour.
        it 'returns the expected response data' do
          expect(response_data).to eq(expected_response)
        end

        it 'returns no errors' do
          expect(response_errors).to be_empty
        end
      end

      context 'when the user has no articles' do
        # Scoping: another user's record must be excluded.
        before { FactoryBot.create(:article, author: FactoryBot.create(:user)) }

        it 'returns an empty list' do
          expect(response_data).to eq({ 'articles' => [] })
        end
      end
    end
  end
end
```

## Why these choices

- **`let!` for fixtures.** The records must exist before the query executes; `let!` forces
  creation in a `before` hook.
- **Whole-shape `eq(expected_response)`.** For a read query the full returned structure is the
  contract, so one equality assertion is clearer than many field pokes.
- **Cover empty and scoping cases.** "no articles" and "another user's articles excluded" are
  the two failure modes a list query most often gets wrong.
