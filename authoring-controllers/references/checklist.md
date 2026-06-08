# Authoring Checklist — Controllers


## Placement & shape

- [ ] Lives in the right engine (`apis/v1/app/controllers/v1/...` for REST; the feature
      engine for HTML).
- [ ] Inherits a base controller that includes error-handling + authorization concerns.
- [ ] Actions are thin: parse → engine story (writes) / registry query (reads) → render
      in callbacks.
- [ ] Names no container constant (use case, query, form, model) — engine sibling story,
      or query resolved through the engine registry, only (ruling 15/16). Scaffold the
      slice with `bin/rails generate layers:api_endpoint <resource>/<action>`.


## Mutating actions

- [ ] `before_action` guards validate request shape and existence.
- [ ] JSON:API: forwards `permit`ted raw params (`parsed_params` merges the raw body) to
      the story — the use case builds the form, not the controller.
- [ ] Calls `UserStories::<Engine>::....call(current_authorization:, **params, listener:
      self, on_success:, on_failure:)`.
- [ ] Public callback methods render success and failure responses — and nothing else does.
- [ ] HTML: `flash.now` + `render` on failure, `flash` + `redirect_to` on success; messages
      via `I18n.t`; failure callbacks that ignore the payload take `(*)`.
- [ ] Params parsing / look-ups in private methods.


## Reads

- [ ] Reads resolve a query through the engine registry
      (`Engine.configuration.queries[:name].new(authorization: current_authorization)`),
      then render through a serializer.


## Cross-cutting

- [ ] Authentication/authorization in a concern; `current_authorization`/`current_user_account`
      from it.
- [ ] Look-ups by `uuid`, scoped to the current identity — never unscoped or by numeric id.
- [ ] Errors via shared `rescue_from` + error serializer, not ad-hoc rescues.
- [ ] JSON:API responses via serializers + one `render_json_api` helper.


## Boundaries

- [ ] No business logic, transactions, or orchestration in the controller.


## Verify

- [ ] Request spec following [[testing-rails-requests]] covers success + failure paths
      and the route's security posture.
