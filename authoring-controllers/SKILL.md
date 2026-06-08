---
name: authoring-controllers
title: Authoring Controllers
description: How to write thin controllers that delegate work to use cases or user stories as listener and render the outcome - JSON:API controllers via serializers, HTML controllers via flash/redirect. Use when adding or changing controllers in the app or an engine.
category: architecture
status: active
version: 1.2
applies_to:
  - Ruby
  - Rails
  - JSON:API
  - Layers::BaseLayer
priority: REQUIRED
triggers:
  - write a controller
  - new controller action
  - REST endpoint
  - json api controller
  - html controller action
anti_triggers:
  - graphql mutation/resolver
  - use case internals
  - model logic
user_invocable: true
last_reviewed_at: 2026-06-08
---


# Authoring Controllers

Controllers are **thin delivery adapters**: parse and validate the request shape, hand the
work to a use case or user story, and render the outcome. Business logic lives below; the
controller is the layer object's **listener**. Two flavours share that shape — **JSON:API
controllers** render through serializers; **HTML controllers** render templates, flash, and
redirects.


## Required Reading

```text
common_agent_skills/derisk_layers/rails-app-architecture/SKILL.md
common_agent_skills/derisk_layers/authoring-use-cases/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-example.md   # JSON:API and HTML controllers, annotated
references/checklist.md           # authoring checklist
```

Render with [[authoring-serializers]]; reads via [[authoring-query-objects]]; test with
[[testing-rails-requests]].


## Placement

REST APIs live in a versioned engine: `apis/v1/app/controllers/v1/<resource>_controller.rb`.
A base `V1::ApplicationController` includes cross-cutting concerns (`V1::ErrorHandling`,
`V1::Authorization`) and a `render_json_api` helper. HTML controllers live in their feature
engine (`engines/<engine>/app/controllers/...`) under that engine's base controller.


## Anatomy of a mutating action (JSON:API)

A REST controller lives in an api engine, so it obeys ruling 15/16: it never names a
container use case or builds a container form. It delegates to its **engine sibling
user story** (engine-owned — naming it is fine), which is the fast exit to the
container use case via the registry; the use case builds its own form peer. Generate
the whole slice with `bin/rails generate layers:api_endpoint <resource>/<action>`.

1. `before_action` guards validate request shape / existence (return rendered errors).
2. Call the engine's user story as a class method, controller as listener, forwarding
   the credential and the permitted raw params:
   ```ruby
   UserStories::V1::Profiles::Update.call(
     current_authorization: current_authorization,
     profile_id: params[:uuid],
     **permitted_params,
     listener: self,
     on_success: :update_succeeded,
     on_failure: :update_failed,
   )
   ```
3. Define the callback methods (public) that render the response:
   ```ruby
   def update_succeeded(profile:)
     render_json_api(profile, serializer: V1::ProfileSerializer)
   end

   def update_failed(errors: nil)
     render_json_api_errors(errors)
   end
   ```
4. Keep params parsing and look-ups in private methods.


## Anatomy of an HTML action

Same listener shape; the work is usually a **user story**, and the callbacks speak
session / flash / redirect:

```ruby
def create
  UserStories::Auth::AuthenticateUserAccount.call(
    password: params[:password],
    user_account: user_account,

    listener: self,
    on_failure: :login_failure,
    on_success: :login_successful,
  )
end

def login_failure(*)
  flash.now[:alert] = I18n.t('auth.login.failure')
  render :new, status: :unprocessable_entity and return
end

def login_successful(user_account: nil)
  session[:user_account_id] = user_account.signed_id(purpose: :auth, expires_in: 7.days)

  flash[:notice] = I18n.t('auth.login.success')
  redirect_to(session.delete(:return_to) || collab.feed_path) and return
end
```

- Failure callbacks that ignore the payload take `(*)`.
- `flash.now` + `render` for failures; `flash` + `redirect_to` for success.
- Messages via `I18n.t`; cross-engine paths via route proxies (`collab.feed_path`).


## Reads

- A simple show renders directly through a serializer — no layer object needed.
- Collection reads go through a **query object**, memoized in private methods, scoped by
  the current identity:

```ruby
def index
  render_json_api(
    engagements,
    serializer: V1::EngagementSerializer,
    collection: true,
  )
end


private

def engagements
  @engagements ||= engagements_query.all
end

def engagements_query
  @engagements_query ||= Queries::IdentityScoped::EngagementsQuery.new(
    current_user_account.identity,
  )
end
```


## Rules

- The controller **decides nothing** about the domain; it translates HTTP ⇄ layer object.
- Layer objects are invoked with `.call(listener: self, on_success:, on_failure:)`; the
  callbacks are where rendering happens — and they are the ONLY place.
- Records are looked up by `uuid` (the public identifier), scoped to the current identity.
- Errors are handled by a shared concern via `rescue_from` + an error serializer, not ad-hoc
  rescues scattered in actions.
- Authentication/authorization live in a concern (`before_action`); expose `current_authorization`
  / `current_user_account` there.
- JSON:API responses go through serializers and a single `render_json_api` helper.


## Avoid

- business logic, transactions, or multi-step orchestration in the controller (use a use case
  or user story).
- building responses by hand instead of via serializers.
- duplicating error handling that belongs in the shared concern.
- unscoped or id-based look-ups — scope by identity, find by uuid.
