# Request Flow — A Write Traced Through the Layers

A concrete trace of "update a profile" through every layer, showing who calls whom and who
reports what. Neutral domain.

## REST (apis/v1)

1. **Router → `V1::ProfilesController#update`.**
   `before_action`s validate the JSON:API payload shape and that the record exists.
2. **Controller builds a form** from permitted params:
   `form = Forms::V1::ProfileUpdate.new(profile: profile, **profile_params)`.
3. **Controller calls the use case, as listener:**
   ```ruby
   UseCases::Profiles::Update.call(form: form, listener: self,
                                   on_success: :update_succeeded, on_failure: :update_failed)
   ```
4. **Use case** guards `return failure(form:) unless form.valid?`, then
   `ActiveRecord::Base.transaction { profile.update!(...) }`, then `success(profile:)` (or
   `failure(form:)` on `RecordInvalid`).
5. **Use case calls back the listener** — the controller's `update_succeeded(profile:)` or
   `update_failed(form:)`.
6. **Controller renders** via `render_json_api(profile, serializer: V1::ProfileSerializer)`
   or `render_form_errors`.

The form validated; the use case wrote transactionally; the model persisted; the serializer
presented. The controller only translated and rendered.

## GraphQL (apis/graph)

1. **Schema → `Graph::Mutations::UpdateProfile`** (a `Layers::Graphql::BaseEndpoint`).
   It declares `user_story 'user_stories/graph/profiles/update'` and
   `user_story_arg :current_authorization` (from `context`).
2. **`BaseEndpoint#resolve`** runs the user story with `listener: self`, merging GraphQL
   arguments with the context-derived credential.
3. **User story** finds the profile, authorizes the identity, updates (often by delegating to
   the same `UseCases::Profiles::Update`), and reports `success(profile:)` /
   `failure(errors:)`.
4. **User story calls back** the mutation's `on_success` / `on_failure`, which return the
   `{ profile, errors }` payload.

Same use case, same form, two delivery adapters. Nothing below the adapter knows whether the
caller was REST or GraphQL — that is the point of the listener boundary.

## Reads

A read skips the use case: the controller (or a user story / resolver) builds a query object
(`Queries::IdentityScoped::ProfilesQuery.new(current_authorization)`), applies
`order`/`page`/`per`, and renders the relation through a serializer.
