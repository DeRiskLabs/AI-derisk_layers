# Annotated Example — GraphQL Mutation Acceptance Spec

Neutral domain: a `createArticle` mutation. Annotated.


## The Object Under Test

The mutation being exercised, compact — a pure declaration (fully annotated in
[[authoring-graphql-mutations]]). The spec posts through the whole stack: schema → this
mutation → `Layers::Graphql::BaseEndpoint` → the `user_stories/graph/articles/create`
user story.

```ruby
module Graph
  module Mutations
    module Articles
      class CreateArticle < Graph::Mutations::ApplicationMutation
        description 'Creates a new article'

        argument :title, String, required: true,
          description: 'The title of the article'

        field :article, Types::Articles::Type, null: true,
          description: 'The created article'
        field :errors, [Types::Base::ErrorType], null: true,
          description: 'Errors encountered during article creation'

        user_story 'user_stories/graph/articles/create'
        user_story_arg :current_identity

        def on_success(article: nil)
          { article: article, errors: [] }
        end

        def on_failure(errors: nil)
          { article: nil, errors: execution_errors_for(errors) }
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

# %i[request acceptance] is what mixes in GraphQLResponseHelpers (parsed_response,
# response_data, response_errors). Without both types those helpers are absent.
RSpec.describe 'GraphQL Mutation: createArticle', type: %i[request acceptance] do
  describe 'A valid GraphQL request' do
    # The document as a string. Variables are declared in the operation signature.
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

    # Variables as a JSON string; interpolate lets so contexts can vary one input.
    let(:variables) { %({ "title": "#{title}" }) }
    let(:params)    { { query: query, variables: variables } }
    let(:headers)   { {} }

    # Dig the payload out once; default errors to [] so empty-state assertions read cleanly.
    let(:response_data)  { JSON.parse(response.body)['data'] }
    let(:article_data)   { response_data&.dig('createArticle', 'article') }
    let(:article_errors) { response_data&.dig('createArticle', 'errors') || [] }

    # The single POST is the action under test.
    execute do
      post '/graphql', params: params.to_json, headers: headers
    end

    context 'with an authenticated user' do
      include_context 'with api authentication'
      let(:headers) { graphql_authenticated_headers }

      context 'with a valid title' do
        it_behaves_like 'requires authentication'

        let(:title) { 'Hello World' }

        # Persistence change → block matcher (post inside the expectation).
        it 'creates an article' do
          expect { post '/graphql', params: params.to_json, headers: headers }
            .to change(Article, :count).by(1)
        end

        it 'returns the title' do
          expect(article_data['title']).to eq(title)
        end

        it 'returns no errors' do
          expect(article_errors).to be_empty
        end
      end

      context 'with a blank title' do
        let(:title) { '' }

        it 'does not create an article' do
          expect { post '/graphql', params: params.to_json, headers: headers }
            .not_to change(Article, :count)
        end

        it 'returns an error message' do
          expect(article_errors.first['message']).to eq("Title can't be blank")
        end

        it 'returns the error path' do
          expect(article_errors.first['path']).to eq(['createArticle', 'title'])
        end
      end
    end
  end
end
```

## Why these choices

- **`type: %i[request acceptance]`** is load-bearing: the response helpers are included only
  for specs with both types under `spec/acceptance/graph`.
- **Dig helpers as lets** keep each `it` to a single, readable assertion on one field/error.
- **`errors` default to `[]`** so `be_empty` works whether or not the key is present.
- **Mutations assert field-by-field** plus `errors`; persistence is checked with a count
  block matcher.
