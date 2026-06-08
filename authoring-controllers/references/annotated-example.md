# Annotated Examples — Controllers

Two annotated controllers: a JSON:API resource controller (neutral domain:
`V1::ProfilesController`) and an HTML controller (a sessions login flow). Both live in
api/feature engines, so they obey ruling 15/16: a controller never names a container
use case, query, form, or model — it delegates to its **engine sibling user story**
(writes) or resolves a **query through the engine registry** (reads). Request specs for
both flavours: [[testing-rails-requests]].


## JSON:API Controller

```ruby
# frozen_string_literal: true

module V1
  class ProfilesController < V1::ApplicationController   # includes ErrorHandling + Authorization
    before_action :validate_json_api_payload, only: %i[update]
    before_action :validate_type, only: %i[update]

    def show
      # A read: ask the registry-resolved, authorization-scoped query. Out-of-reach
      # records simply are not found.
      profile = profiles_query.find_by(uuid: params[:uuid])
      return render_json_api_error(:not_found, resource_type: 'profile', status: :not_found) unless profile

      render_json_api(profile, serializer: V1::ProfileSerializer,
                               includes: V1::ProfileSerializer::STANDARD_INCLUDES)
    end

    def update
      # A write: delegate to the engine sibling story, forwarding the credential and
      # the permitted raw params. The story exits to the use case via the registry; the
      # use case builds its form peer. The controller is the listener.
      UserStories::V1::Profiles::Update.call(
        current_authorization: current_authorization,
        profile_id: params[:uuid],
        **profile_params,
        listener: self,
        on_success: :update_succeeded,
        on_failure: :update_failed,
      )
    end

    ## Callbacks (public — the story calls these back)

    def update_succeeded(profile:)
      render_json_api(profile, serializer: V1::ProfileSerializer,
                               includes: V1::ProfileSerializer::STANDARD_INCLUDES)
    end

    def update_failed(errors: nil)
      render_json_api_errors(errors)
    end


    private

    # The query is resolved through the engine registry and constructed with the
    # credential — never `Queries::...` named directly (ruling 15).
    def profiles_query
      V1.configuration.queries[:profiles].new(authorization: current_authorization)
    end

    def profile_params
      parsed_params.require(:data).require(:attributes).permit(:first_name, :last_name, :phone)
    end

    # JSON:API clients send a raw JSON body; merge it into params once.
    def parsed_params
      @parsed_params ||= params.merge(JSON.parse(request.raw_post))
    end
  end
end
```


## HTML Controller

```ruby
# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    skip_before_action :authenticate_user_account!, only: %i[new create]

    def new; end

    def create
      # The work is a user story; the controller is its listener. The story looks up the
      # account (via its query registry) and authenticates — the controller names no model.
      UserStories::Auth::AuthenticateUserAccount.call(
        email: params[:email],
        password: params[:password],
        listener: self,
        on_failure: :login_failure,
        on_success: :login_successful,
      )
    end

    ## Callbacks

    # The failure payload is irrelevant to rendering — take (*) and ignore it.
    def login_failure(*)
      flash.now[:alert] = I18n.t('auth.login.failure')   # flash.now: we render, not redirect
      render :new, status: :unprocessable_entity and return
    end

    def login_successful(user_account: nil)
      session[:user_account_id] = user_account.signed_id(purpose: :auth, expires_in: 7.days)

      flash[:notice] = I18n.t('auth.login.success')
      redirect_to(session.delete(:return_to) || collab.feed_path) and return
    end

    def destroy
      session[:user_account_id] = nil
      flash[:notice] = I18n.t('auth.logout.success')
      redirect_to auth.root_path
    end
  end
end
```


## Why these choices

- **Thin actions, nothing container-named.** Actions translate the request and call a
  layer object. Writes go to the engine sibling story (engine-owned, safe to name);
  reads resolve a query through the engine registry. No use case, form, query, or model
  constant is named in the engine (ruling 15/16) — the lookup and the form both live
  past the boundary.
- **Controller as listener.** `listener: self` + `on_success:`/`on_failure:` means the
  layer object stays caller-agnostic, and the controller renders in named callbacks. The
  same story is reused unchanged from tests.
- **Reads vs writes (CQS).** `show` resolves an authorization-scoped query and renders;
  writes go through a story. The query's scope hides out-of-reach records, so off-limits
  reads as not-found — no 403 oracle.
- **uuid at the edges.** Look-ups use the public identifier; the scoping is the
  credential's, applied where the query is constructed.
- **Guards via `before_action`.** Request-shape checks short-circuit with rendered
  JSON:API errors before the action runs; unexpected errors are caught by
  `V1::ErrorHandling`'s `rescue_from`, not per-action rescues.
- **Two flavours, one shape.** The HTML controller follows the identical listener
  pattern; only the rendering vocabulary changes (flash/session/redirect vs serializers).
