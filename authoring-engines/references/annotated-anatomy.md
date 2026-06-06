# Annotated Anatomy — Engines

The house shape for a mountable engine, grounded in working engines. Shown for a
feature engine `invoicing`; the API-engine variants follow.


## Layout

```text
engines/invoicing/
├── invoicing.gemspec
├── Gemfile                      # gemspec + dev tooling; the container consumes via path
├── Rakefile
├── README.md
├── app/
│   ├── controllers/invoicing/   # engine-namespaced: Invoicing::ProfilesController
│   ├── views/invoicing/
│   ├── jobs/invoicing/
│   ├── mailers/invoicing/
│   └── lib/                     # autoload root: app-wide layer families
│       ├── forms/invoicing/
│       ├── use_cases/invoicing/        # incl. base_use_case.rb
│       └── user_stories/invoicing/     # incl. base_user_story.rb
├── config/
│   ├── routes.rb
│   └── locales/
└── lib/
    ├── invoicing.rb             # requires version + engine
    └── invoicing/
        ├── version.rb
        └── engine.rb
```


## invoicing.gemspec

```ruby
# frozen_string_literal: true

require_relative 'lib/invoicing/version'

Gem::Specification.new do |spec|
  spec.name        = 'invoicing'
  spec.version     = Invoicing::VERSION
  spec.authors     = ['']
  spec.summary     = 'Invoicing Engine'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'rails', '>= 8.0.1'
  spec.add_dependency 'sidekiq'
  spec.add_dependency 'slim-rails'
end
```

The engine declares `rails` and every Rails-facing dependency it owns. An unbuilt gem:
consumed from the path, never built or published.


## lib/invoicing.rb — the root file

```ruby
# frozen_string_literal: true

require 'invoicing/version'
require 'invoicing/engine'

module Invoicing
end
```

The engine's `app/` directories are autoloaded by Rails; only `lib/` needs requires.


## lib/invoicing/engine.rb — feature-engine stance

```ruby
# frozen_string_literal: true

module Invoicing
  class Engine < ::Rails::Engine
    isolate_namespace Invoicing

    config.generators do |g|
      g.template_engine :slim
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end

    initializer 'invoicing.middleware' do |_app|
      config.middleware.delete ActionDispatch::Cookies
      config.middleware.delete ActionDispatch::Session::CookieStore
      config.middleware.delete ActionDispatch::Flash

      middleware.use ActionDispatch::Cookies
      middleware.use Rails.application.config.session_store, Rails.application.config.session_options
      middleware.use ActionDispatch::Flash
      middleware.use Rack::MethodOverride
    end

    config.i18n.load_path += Dir[root.join('config', 'locales', '**', '*.{rb,yml}')]
  end
end
```

The middleware initializer is the session dedup: the engine drops its own
cookie/session/flash middleware and re-uses the main application's, so one session
spans app and engines and users never carry duplicate cookies.


## lib/v1/engine.rb — API-engine stance

```ruby
# frozen_string_literal: true

module V1
  class Engine < ::Rails::Engine
    isolate_namespace V1

    config.api_only = true

    initializer 'v1.api_mode' do |_app|
      config.debug_exception_response_format = :api
      config.action_controller.default_protect_from_forgery = false

      config.session_store = :null_store
      config.middleware.delete ActionDispatch::Cookies
      config.middleware.delete ActionDispatch::Session::CookieStore
      config.middleware.delete ActionDispatch::Flash
    end

    initializer 'v1.set_api_format' do |_app|
      ActiveSupport.on_load(:action_controller) do
        config.default_render_format = :json
      end
    end
  end
end
```

No session, no cookies, no forgery protection, JSON by default. The GraphQL engine
shares the `api_only` stance; its schema and type wiring live in the
authoring-graphql skill's engine-anatomy reference.


## config/routes.rb — engine side

```ruby
# frozen_string_literal: true

Invoicing::Engine.routes.draw do
  scope 'invoicing' do
    resources :statements, param: :uuid, only: %i[index show]

    root to: 'home#index'
  end
end
```

The feature engine owns its path prefix via `scope`; the container mounts it at `/`.


## Container wiring

```ruby
# Gemfile
path 'engines' do
  gem 'invoicing'
end
```

```ruby
# config/routes.rb
mount Invoicing::Engine, at: '/'
mount V1::Engine, at: '/api', as: :api
mount Graph::Engine, at: '/'
```


## Engine-local bases

```ruby
# app/lib/use_cases/invoicing/base_use_case.rb
module UseCases
  module Invoicing
    class BaseUseCase < Layers::BaseLayer
    end
  end
end
```

```ruby
# app/lib/user_stories/invoicing/base_user_story.rb
module UserStories
  module Invoicing
    class BaseUserStory < Layers::BaseLayer
    end
  end
end
```

Note the namespace: layer objects join the app-wide `UseCases::` / `UserStories::`
families (the engine's `app/lib` is an autoload root); only Rails-facing classes take
the engine constant. Bases stay behavioural — declarations are per-class and do not
inherit.
