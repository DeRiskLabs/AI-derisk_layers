# common_agent_skills/derisk_layers/authoring-controllers/references/annotated-example.md


# Annotated Examples — Controllers

Two annotated controllers: a JSON:API resource controller (neutral domain:
`V1::ProfilesController`) and an HTML controller (a sessions login flow). Request specs
for both flavours: [[testing-rails-requests]].


## JSON:API Controller

```ruby
# frozen_string_literal: true

module V1
  class ProfilesController < V1::ApplicationController   # includes ErrorHandling + Authorization
    before_action :validate_profile_found
    before_action :validate_json_api_payload, only: %i[update]
    before_action :validate_type, only: %i[update]

    def show
      # Reads render directly through a serializer; no layer object for a simple read.
      render_json_api(profile, serializer: V1::ProfileSerializer,
                               includes: V1::ProfileSerializer::STANDARD_INCLUDES)
    end

    def update
      # 1. Build the form from permitted params.
      form = Forms::V1::ProfileUpdate.new(profile: profile, **profile_params)

      # 2. Hand it to the use case; the controller is the listener.
      UseCases::Profiles::Update.call(
        form: form,
        listener: self,
        on_success: :update_succeeded,
        on_failure: :update_failed,
      )
    end

    ## Callbacks (public — the use case calls these back)

    def update_succeeded(profile:)
      render_json_api(profile, serializer: V1::ProfileSerializer,
                               includes: V1::ProfileSerializer::STANDARD_INCLUDES)
    end

    def update_failed(form:)
      render_form_errors(errors: form.errors.map do |error|
        V1::ErrorSerializer::Error.new(attribute: error.attribute, message: error.message)
      end)
    end


    private

    # Look-ups are identity-scoped and by uuid — the public identifier.
    def profile
      @profile ||= Profile.where(identity: current_user_account.identity)
                          .find_by(uuid: params[:uuid])
    end

    def profile_params
      parsed_params.require(:data).require(:attributes).permit(:first_name, :last_name, :phone)
    end

    # JSON:API clients send a raw JSON body; merge it into params once.
    def parsed_params
      @parsed_params ||= params.merge(JSON.parse(request.raw_post))
    end

    def validate_profile_found
      return if profile
      render_json_api_error(:not_found, resource_type: 'profile', status: :not_found)
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
      # The work is a user story; the controller is its listener.
      UserStories::Auth::AuthenticateUserAccount.call(
        password: params[:password],
        user_account: user_account,

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


    private

    def user_account
      @user_account ||= UserAccount.joins(identity: :email_addresses)
                                   .find_by(email_addresses: { email: params[:email] })
    end
  end
end
```


## Why these choices

- **Thin actions.** `update`/`create` only build inputs and call the layer object. No
  transaction, no business rules — those live in the use case / user story.
- **Controller as listener.** `listener: self` + `on_success:`/`on_failure:` means the layer
  object stays caller-agnostic, and the controller renders in named callbacks. The same use
  case is reused unchanged from GraphQL or tests.
- **Reads vs writes.** `show` renders straight through a serializer; collection reads go
  through an identity-scoped query object; only writes go through a use case.
- **uuid + identity scoping.** Look-ups use the public identifier and are scoped to the
  current identity, so authorization-by-construction backs up the explicit checks.
- **Guards via `before_action`.** Request-shape and existence checks short-circuit with
  rendered JSON:API errors before the action runs.
- **Shared error handling.** Unexpected errors are caught by `V1::ErrorHandling`'s
  `rescue_from`, not per-action rescues.
- **Two flavours, one shape.** The HTML controller follows the identical listener pattern;
  only the rendering vocabulary changes (flash/session/redirect vs serializers).
