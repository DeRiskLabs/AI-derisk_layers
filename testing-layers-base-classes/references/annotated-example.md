# common_agent_skills/derisk_layers/testing-layers-base-classes/references/annotated-example.md


# Annotated Example — Layers Base Class / DSL Module Specs

Two annotated specs: the base class (`Layers::BaseLayer`) and a DSL module
(`Layers::DSL::Inputs`).


## Base class — composition, initialization, reporting

```ruby
# frozen_string_literal: true

require 'layers_spec_helper'

RSpec.describe Layers::BaseLayer do

  # Composition contract: each one-liner pins one promised module.
  it { expect(described_class.included_modules).to include(Layers::DSL::Observers) }
  it { expect(described_class.included_modules).to include(Layers::DSL::Inputs) }
  it { expect(described_class.included_modules).to include(Layers::DSL::NullListener) }
  it { expect(described_class.included_modules).to include(Layers::DSL::CallbackDefaults) }
  it { expect(described_class.included_modules).to include(Layers::DSL::ClassCallable) }


  describe '#initialize' do
    # Initialization IS the contract here, so the constructor is tested directly.
    # Allocate in subject, then #initialize itself is the action — inside execute.
    subject(:layer) { described_class.allocate }

    let(:init_args) { {} }

    execute do
      layer.send(:initialize, **init_args)
    end

    context 'with no arguments' do
      it 'sets the null listener' do
        expect(layer.listener).to be_a(Naught::BasicObject)
      end

      it 'sets the default failure callback' do
        expect(layer.on_failure).to eq(layer.on_failure_default)
      end

      it 'sets the default success callback' do
        expect(layer.on_success).to eq(layer.on_success_default)
      end
    end

    context 'with a custom listener' do
      let(:custom_listener) { double('Listener') }
      let(:init_args) { { listener: custom_listener } }

      # Identity, so `be` — `eq` would silently pass through a future == override.
      it 'sets the custom listener' do
        expect(layer.listener).to be(custom_listener)
      end
    end

    context 'with custom callbacks' do
      let(:init_args) do
        {
          on_failure: :custom_failure,
          on_success: :custom_success,
        }
      end

      it 'sets the custom failure callback' do
        expect(layer.on_failure).to eq(:custom_failure)
      end

      it 'sets the custom success callback' do
        expect(layer.on_success).to eq(:custom_success)
      end
    end
  end


  # success/failure are private with no public caller in the base, so a concrete
  # subclass exercises them through a real #call. The observer is a callable recording
  # into a local — behavioural, instead of expecting notify_observers on self.
  describe 'success/failure handling' do
    let(:listener) { spy('Listener') }
    let(:notifications) { [] }

    describe '#success' do
      subject(:layer) { success_class.new(listener: listener) }

      let(:success_class) do
        recorder = notifications
        Class.new(described_class) do
          observer -> { recorder << :success }, of_event: :success

          def call
            success(result: true)
          end
        end
      end

      execute do
        layer.call
      end

      it 'notifies success observers' do
        expect(notifications).to include(:success)
      end

      it 'calls the success callback on the listener' do
        expect(listener).to have_received(:on_success).with(result: true)
      end
    end
  end
end
```


## DSL module — assert it endows includers

```ruby
# frozen_string_literal: true

require 'layers_spec_helper'

RSpec.describe Layers::DSL::Inputs do
  describe 'Class Methods' do

    # An anonymous class is the cheapest, self-contained way to include and exercise a module.
    subject(:test_class) { Class.new.include(described_class) }

    it { is_expected.to respond_to(:required) }
    it { is_expected.to respond_to(:optional) }

    describe '.required' do
      subject(:test_class) do
        Class.new do
          include Layers::DSL::Inputs
          required :foo
        end
      end

      it 'tracks the input' do
        expect(test_class.required_inputs).to include(:foo)
      end

      it 'endows instances with a reader' do
        expect(test_class.new(foo: 1)).to respond_to(:foo)
      end
    end
  end

  describe 'Instance Methods' do
    subject(:input_object) { test_class.allocate }

    let(:test_class) do
      Class.new do
        include Layers::DSL::Inputs
        required :foo
      end
    end

    describe '#initialize' do
      let(:test_args) { { foo: true } }

      context 'with valid inputs' do
        execute do
          input_object.send(:initialize, **test_args)
        end

        it 'sets the inputs hash' do
          expect(input_object.inputs).to eq(test_args)
        end
      end

      # Raising case: block expectation inside it (see always-execute-rspec Exceptions),
      # still through allocate + send so no fixture class is constructed twice.
      context 'with missing required inputs' do
        it 'raises MissingRequiredInputs' do
          expect do
            input_object.send(:initialize)
          end.to raise_error(Layers::DSL::MissingRequiredInputs)
        end
      end
    end
  end
end
```


## Why these choices

- **Anonymous classes, not repo fixtures.** A base/module has no behaviour of its own; the
  spec must construct an includer. Inline `Class.new` keeps that throwaway local.
- **`included_modules` one-liners** document the composition contract precisely.
- **`allocate` + `execute { send(:initialize) }`** keeps the constructor — the action under
  test — inside `execute`, with layered `init_args` lets so each context overrides one
  input.
- **Callable observers recording into a local** prove notification behaviourally; expecting
  `notify_observers` on the layer itself would assert a message to self.
- **Assert the real module name.** The file `callback_defaults.rb` defines
  `CallbackDefaults` — not a stale `DefaultCallbacks`.
