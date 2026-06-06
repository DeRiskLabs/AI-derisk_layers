# Annotated Skeleton — Component

What `bin/rails generate layers:component billing` produces under
`components/billing/`, file by file. New components must match this shape whether
generated or written by hand.


## billing.gemspec

```ruby
# frozen_string_literal: true

require_relative 'lib/billing/version'

Gem::Specification.new do |spec|
  spec.name = 'billing'
  spec.version = Billing::VERSION
  spec.authors = ['']
  spec.summary = 'Billing bounded context'
  spec.required_ruby_version = '>= 3.1'

  spec.files = Dir.glob('lib/**/*')
  spec.require_paths = ['lib']

  spec.add_dependency 'layers'
end
```

An unbuilt gem: never built or published, consumed straight from the path. The only
declared dependency is `layers`; add pure-Ruby gems the domain needs, never `rails`.


## Gemfile

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rspec'
```

This Gemfile exists for the isolated suite: `BUNDLE_GEMFILE=Gemfile bundle exec rspec`
resolves against it, not the application's bundle. While `layers` is unreleased, wire
its private source in here before running in isolation.


## lib/billing.rb — the root constant

```ruby
# frozen_string_literal: true

require 'layers'
require 'billing/version'
require 'billing/repository_registry'
require 'billing/configuration'

module Billing
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
```

- Explicit requires — there is no autoloading in a component. Every new file gets a
  `require` here or in a file reached from here.
- `configure` is the container's filling point (the boot initializer);
  `configuration` is the component's own access point at runtime.
- The public interface grows here: class methods wrapping use cases.


## lib/billing/version.rb

```ruby
# frozen_string_literal: true

module Billing
  VERSION = '0.1.0'
end
```


## lib/billing/repository_registry.rb

```ruby
# frozen_string_literal: true

module Billing
  class RepositoryRegistry < Layers::BaseRegistry
    alias register_repository register
    alias register_repositories register
    alias remove_repository remove
  end
end
```

One `register(**entries)` implementation behind domain-named aliases — `register` takes
one pair or many, so both aliases are the same method. A registry subclass may also
override the private `defaults` hook (returns `{}`) to ship seed entries; registration
overrides them.


## lib/billing/configuration.rb

```ruby
# frozen_string_literal: true

module Billing
  class Configuration
    attr_writer :repo

    delegate :register_repository, :register_repositories, to: :repo

    def repo
      @repo ||= RepositoryRegistry.new
    end
  end
end
```

- This is the configuration house style in miniature: a setting with a default is
  `attr_writer` plus a memoized reader carrying that default. Grow new settings the
  same way; `attr_accessor` only for genuinely nil-default flags.
- `attr_writer :repo` is also the spec seam: swap the whole registry
  (`Billing.configuration.repo = { invoice: fake }`) — anything answering `[]` serves.
- The delegators let the container's configure block read naturally
  (`config.register_repository invoice: 'Invoice'`).


## spec/spec_helper.rb

```ruby
# frozen_string_literal: true

require 'billing'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
```

Requires the component only. No Rails, no database, no container app — if a spec needs
one of those, the code under test is in the wrong place.


## spec/billing_spec.rb

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Billing do
  it 'has a version' do
    expect(Billing::VERSION).not_to be_nil
  end
end
```


## .rubocop.yml

```yaml
inherit_from: ../../.rubocop.yml
```

The component obeys the application's RuboCop config.


## README.md

States the component's contract at its door: the public interface rule, the
registration the container must perform at boot, the consumption line for the
application Gemfile (`path 'components' do gem 'billing' end`), and how to run the
isolated suite.


## bin/test_components (application root; created with the first component)

```bash
#!/usr/bin/env bash
set -uo pipefail

status=0
for component in components/*/; do
  [ -f "${component}Gemfile" ] || continue
  echo "==> ${component}"
  (cd "$component" && BUNDLE_GEMFILE=Gemfile bundle exec rspec) || status=1
done

exit $status
```

Runs every component's suite under its own bundle.
