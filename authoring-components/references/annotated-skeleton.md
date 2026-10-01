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
  spec.required_ruby_version = '>= 3.4'

  spec.files = Dir.glob('lib/**/*')
  spec.require_paths = ['lib']

  spec.add_dependency 'layers'
  spec.add_dependency 'zeitwerk', '~> 2.6'
end
```

An unbuilt gem: never built or published, consumed straight from the path. Its baseline
runtime dependencies are `layers` and the component-owned `zeitwerk` loader; add
pure-Ruby gems the domain needs, never `rails`.
The generator sets `required_ruby_version` to the language major/minor of the application
runtime that invokes it; `3.4` is the value for this example.


## Gemfile

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Runtime
# -------

gem 'activemodel', '7.2.4'
gem 'activesupport', '7.2.4'
gem 'layers', git: 'git@github.com:DeRiskLabs/layers.git', branch: 'main'


group :development, :test do
  gem 'always_execute'
  gem 'rspec'
end
```

This Gemfile exists for the isolated suite: `BUNDLE_GEMFILE=Gemfile bundle exec rspec`
resolves against it, not the application's bundle. The explicit private source resolves
the unreleased `layers` gem while the gemspec continues to declare the runtime dependency.
The generator pins Active Model and Active Support exactly to the generating application's
Rails version; `7.2.4` is the container version in this example. `always_execute` is
mandatory in every isolated component suite.


## lib/billing.rb — the root constant

```ruby
# frozen_string_literal: true

require 'layers'
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module Billing
end

require 'billing/configuration'
```

- The component owns this Zeitwerk loader. Conventional constants beneath `lib/billing/`
  autoload without placing `components/` in the container's Rails loaders.
- `configuration.rb` is explicitly required because it publishes methods on the root
  constant; defining the root module first keeps that boundary explicit.
- The public interface grows on `Billing`: class methods wrapping use cases.


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
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end

  class Configuration
    attr_writer :repo

    delegate :register_repository, :register_repositories, to: :repo

    def repo
      @repo ||= RepositoryRegistry.new
    end
  end
end
```

- `configure` is the container's filling point (the boot initializer);
  `configuration` is the component's own access point at runtime. Both stay in this
  configuration file rather than the root loader file.
- This is the configuration house style in miniature: a setting with a default is
  `attr_writer` plus a memoized reader carrying that default. Grow new settings the
  same way; `attr_accessor` only for genuinely nil-default flags.
- `attr_writer :repo` is also the spec seam: swap the whole registry
  (`Billing.configuration.repo = { invoice: fake }`) — anything answering `[]` serves.
- The delegators let the container's configure block read naturally
  (`config.register_repository invoice: 'Invoice'`).


## .rspec

```text
--require billing_spec_helper
--color
--format documentation
```

RSpec loads the helper named for this component rather than an ambiguous global
`spec_helper`.


## spec/billing_spec_helper.rb

```ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'always_execute'
require 'billing'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
```

Activates the component's own bundle before requiring the testing DSL and component.
This makes direct `rspec` execution from the component directory resolve private/path
dependencies correctly. No Rails, no database, no container app — if a spec needs one
of those, the code under test is in the wrong place.


## spec/billing_spec.rb

```ruby
# frozen_string_literal: true

require 'billing_spec_helper'

RSpec.describe Billing do
  it { is_expected.to respond_to(:configuration) }
  it { is_expected.to respond_to(:configure) }

  it 'has a version' do
    expect(Billing::VERSION).not_to be_nil
  end

  it 'autoloads component internals' do
    expect(Billing::RepositoryRegistry).to be < Layers::BaseRegistry
  end
end
```

The root spec pins the small public interface exposed to consumers. Add an example here
whenever a new root-constant entry point is published.


## spec/billing/configuration_spec.rb

```ruby
# frozen_string_literal: true

require 'billing_spec_helper'

RSpec.describe Billing::Configuration do
  subject(:configuration) { described_class.new }

  describe '#repo' do
    it { is_expected.to respond_to(:repo) }
    it { is_expected.to respond_to(:repo=) }

    it 'defaults to the component repository registry' do
      expect(configuration.repo).to be_a(Billing::RepositoryRegistry)
    end
  end

  context 'with an injected repository registry' do
    let(:repo) do
      instance_spy(Billing::RepositoryRegistry,
                   register_repository: nil,
                   register_repositories: nil)
    end

    before do
      configuration.repo = repo
    end

    describe '#register_repository' do
      let(:entry) { { primary: 'PrimaryRecord' } }

      execute do
        configuration.register_repository(**entry)
      end

      it 'delegates the entry to the repository registry' do
        expect(repo).to have_received(:register_repository).with(**entry)
      end
    end

    describe '#register_repositories' do
      let(:entries) do
        { primary: 'PrimaryRecord', secondary: 'SecondaryRecord' }
      end

      execute do
        configuration.register_repositories(**entries)
      end

      it 'delegates the entries to the repository registry' do
        expect(repo).to have_received(:register_repositories).with(**entries)
      end
    end
  end
end
```

The configuration spec proves the default seam and both registration delegators. Actions
belong in `execute` so every focused example still performs its setup consistently.


## .rubocop.yml

```yaml
inherit_from: ../../.rubocop.yml

Gemspec/RequireMFA:
  Enabled: false
```

The component obeys the application's RuboCop config. The MFA metadata cop is disabled
at this boundary because components are unbuilt, unpublished gems.


## README.md

States the component's contract at its door: the public interface rule, that the empty
scaffold has no registered repositories, how the container may register repositories
when a real persistence need appears, the consumption line for the application Gemfile
(`path 'components' do gem 'billing' end`), and how to run both isolated and aggregate
suites. Do not invent a sample repository or domain concept merely to demonstrate the
registration syntax.


## bin/test_suite (application root; created when absent)

```bash
#!/usr/bin/env bash
set -euo pipefail

bundle exec rspec

for slice in components/*/ engines/*/ apis/*/; do
  [ -f "${slice}Gemfile" ] || continue

  echo "==> ${slice}"
  (
    cd "$slice"
    if ! BUNDLE_GEMFILE=Gemfile bundle check >/dev/null 2>&1; then
      BUNDLE_GEMFILE=Gemfile bundle install
    fi
    BUNDLE_GEMFILE=Gemfile bundle exec rspec
  )
done
```

Runs the container suite first, then every component, engine, and API suite under its
own bundle. Because it is shared by all slice generators, an existing runner is retained.
