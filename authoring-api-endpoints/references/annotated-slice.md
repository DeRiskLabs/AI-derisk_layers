# Annotated Slice — API Endpoint

What `bin/rails generate layers:api_endpoint orders/create --engine v1` emits, annotated.
Domain: a `POST /orders` create. TODOs are the semantics you fill.


## Container: the use case (`app/lib/use_cases/orders/create.rb`)

```ruby
module UseCases
  module Orders
    class Create < ApplicationUseCase
      required :name # TODO: the raw inputs this use case receives

      emits success: [:thing], failure: [:form] # TODO: name the success payload object

      delegate :valid?, to: :form

      def call
        return failure(form: form) unless valid?

        execute!

        success(thing: nil) # TODO: emit the persisted object
      end


      private

      def form
        @form ||= Forms::Orders::CreateForm.new(name: name) # TODO: build the peer form
      end

      def execute!
        # TODO: persist the form's objects in a transaction
      end
    end
  end
end
```

Raw inputs in; the form is a container peer built here ([[authoring-use-cases]]). The
container can name `Forms::Orders::CreateForm` — they sit at the same level.


## Container: the form (`app/lib/forms/orders/create_form.rb`)

`Forms::Orders::CreateForm < ApplicationForm` — accessors, validations, builders, and the
`report_full_errors_for` whitelist ([[authoring-layers-forms]]).


## Engine: the user story (`apis/v1/app/lib/user_stories/v1/orders/create.rb`)

```ruby
module UserStories
  module V1
    module Orders
      class Create < BaseUserStory
        required :current_authorization # TODO: declare the inputs this story receives

        emits success: [:order], failure: [:errors] # TODO: declare the real payloads

        def call
          use_case.call(**use_case_args)
        end

        def create_succeeded(form:)
          success(order: nil) # TODO: emit the named object the interaction produces
        end

        def create_failed(form: nil, errors: nil)
          failure(errors: errors || form.errors)
        end


        private

        def use_case
          V1.configuration.use_cases[:orders_create]   # resolved, never named (ruling 15)
        end

        def use_case_args
          {
            listener: self,
            on_success: :create_succeeded,
            on_failure: :create_failed,
            **use_case_options,
          }
        end

        def use_case_options
          {} # TODO: the raw inputs the use case requires (e.g. name:, email:)
        end
      end
    end
  end
end
```

`< BaseUserStory` resolves to `UserStories::V1::BaseUserStory` by lexical nesting.


## Engine: the controller (`apis/v1/app/controllers/v1/orders_controller.rb`)

```ruby
module V1
  class OrdersController < ApplicationController
    def create
      UserStories::V1::Orders::Create.call(
        current_authorization: current_authorization,
        listener: self,
        on_success: :create_succeeded,
        on_failure: :create_failed,
        # TODO: permitted params the story forwards to the use case
      )
    end

    def create_succeeded(order:)
      render_json_api(order, serializer: V1::OrderSerializer,
                      status: :created)
    end

    def create_failed(errors: nil)
      render_json_api_errors(errors)
    end
  end
end
```

Names its engine sibling story (allowed); `render_json_api*` come from the engine base
controller. If the controller already exists, only the action + callbacks are injected.


## Engine: the serializer (`apis/v1/app/serializers/v1/order_serializer.rb`)

```ruby
module V1
  class OrderSerializer
    include JSONAPI::Serializer

    # TODO: the attributes this resource exposes
    # attributes :name
  end
end
```


## Wiring (injected)

```ruby
# apis/v1/config/routes.rb
resources :orders, only: %i[create], param: :uuid

# config/initializers/v1.rb
V1.configure do |config|
  config.register_use_case orders_create: 'UseCases::Orders::Create'
end
```

Plus pending request and routing specs under `apis/v1/spec/` naming the cases to cover.
