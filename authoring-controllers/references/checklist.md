# common_agent_skills/derisk_layers/authoring-controllers/references/checklist.md


# Authoring Checklist — Controllers


## Placement & shape

- [ ] Lives in the right engine (`apis/v1/app/controllers/v1/...` for REST; the feature
      engine for HTML).
- [ ] Inherits a base controller that includes error-handling + authorization concerns.
- [ ] Actions are thin: parse → form/inputs → layer object → render in callbacks.


## Mutating actions

- [ ] `before_action` guards validate request shape and existence.
- [ ] JSON:API: builds a form from `permit`ted params (`parsed_params` merges the raw body).
- [ ] Calls `UseCase.call(form:, listener: self, on_success:, on_failure:)` (or a user
      story for orchestrated/HTML flows).
- [ ] Public callback methods render success and failure responses — and nothing else does.
- [ ] HTML: `flash.now` + `render` on failure, `flash` + `redirect_to` on success; messages
      via `I18n.t`; failure callbacks that ignore the payload take `(*)`.
- [ ] Params parsing / look-ups in private methods.


## Reads

- [ ] Simple show renders directly through a serializer.
- [ ] Collections go through a memoized, identity-scoped query object.


## Cross-cutting

- [ ] Authentication/authorization in a concern; `current_identity`/`current_user_account`
      from it.
- [ ] Look-ups by `uuid`, scoped to the current identity — never unscoped or by numeric id.
- [ ] Errors via shared `rescue_from` + error serializer, not ad-hoc rescues.
- [ ] JSON:API responses via serializers + one `render_json_api` helper.


## Boundaries

- [ ] No business logic, transactions, or orchestration in the controller.


## Verify

- [ ] Request spec following [[testing-rails-requests]] covers success + failure paths
      and the route's security posture.
