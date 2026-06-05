# Annotated Example — User Story

Neutral domain: `UserStories::Graph::Articles::Update` — update an article the current
identity authored. The companion spec is the annotated example in [[testing-user-stories]].

```ruby
# frozen_string_literal: true

module UserStories
  module Graph
    module Articles
      class Update < UserStories::Graph::Base   # Base < Layers::BaseLayer + ActiveModel::Validations
        # Declare exactly the inputs the action needs. Lookups arrive as public uuids.
        required :current_identity
        required :id
        optional :title

        def call
          # 1. Find — by uuid, the public identifier. A missing record is an expected
          #    failure, not an exception.
          article = Article.find_by(uuid: id)
          return failure(errors: ['Article not found']) unless article

          # 2. Authorize. Ownership lives in the story, not the use case.
          return failure(errors: ['Not authorized to update this article']) unless authorized?(article)

          # 3. Do the work. Here it is a simple update; for anything transactional or
          #    reused, delegate to a use case instead.
          if article.update(update_attributes)
            success(result: article)
          else
            failure(errors: article.errors)   # validation errors flow back as the errors payload
          end
        end

        private

        def authorized?(article)
          article.author == current_identity
        end

        def update_attributes
          {}.tap { |a| a[:title] = title if title.present? }
        end
      end
    end
  end
end
```


## Why these choices

- **Guard-clause sequence.** `#call` reads top-to-bottom as the story: found? authorized?
  valid? Each failure mode returns early with a clear `errors:` payload.
- **uuid lookups.** The story is driven by delivery adapters, so `id` is the public uuid;
  the numeric primary key never crosses this boundary.
- **`errors:` payload.** GraphQL endpoints and controllers render these; user stories
  standardise on an errors array or an `errors` object so the endpoint stays dumb.
- **Authorization here, not below.** The use case assumes it is allowed to act; deciding
  *whether* to act is the story's responsibility.
- **Delegate real work.** This example updates inline because it is trivial. For a
  transactional, reusable write, call a use case (`UseCases::Articles::Update.call(...)`)
  and forward its outcome — keeping the transactional logic in one place.
