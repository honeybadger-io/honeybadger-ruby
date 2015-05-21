require 'honeybadger/plugins/local_variables'
require 'honeybadger/config'

describe "Local variables integration", order: :defined do
  let(:config) { Honeybadger::Config.new(logger: NULL_LOGGER, debug: true) }

  before do
    Honeybadger::Plugin.instances[:local_variables].reset!
    config[:'exceptions.local_variables'] = config_enabled
  end

  subject { Exception.new }

  context "when binding_of_caller isn't installed", :unless => defined?(::BindingOfCaller) do
    let(:config_enabled) { true }

    it "doesn't install extensions" do
      expect(::Exception).not_to receive(:include).with(Honeybadger::Plugins::LocalVariables::ExceptionExtension)
      Honeybadger::Plugin.instances[:local_variables].load!(config)
    end
  end

  context "when binding_of_caller is installed", :if => defined?(::BindingOfCaller) do
    context "and disabled by configuration" do
      let(:config_enabled) { false }

      it "doesn't install extensions" do
        expect(::Exception).not_to receive(:include).with(Honeybadger::Plugins::LocalVariables::ExceptionExtension)
        Honeybadger::Plugin.instances[:local_variables].load!(config)
      end
    end

    context "and enabled by configuration" do
      let(:config_enabled) { true }

      it "installs the extensions" do
        expect(::Exception).to receive(:include).with(Honeybadger::Plugins::LocalVariables::ExceptionExtension)
        Honeybadger::Plugin.instances[:local_variables].load!(config)
      end

      context "when BetterErrors is detected" do
        before { Object.const_set(:BetterErrors, Class.new) }
        after { Object.send(:remove_const, :BetterErrors) }

        it "skips extension" do
          expect(::Exception).not_to receive(:include)
          Honeybadger::Plugin.instances[:local_variables].load!(config)
        end

        it "warns the logger" do
          expect(config.logger).to receive(:warn).with /better_errors/
          Honeybadger::Plugin.instances[:local_variables].load!(config)
        end
      end

      describe Honeybadger::Plugins::LocalVariables::ExceptionExtension do
        subject do
          # Test in isolation rather than installing the plugin globally.
          Class.new(Exception) do |klass|
            klass.send(:include, Honeybadger::Plugins::LocalVariables::ExceptionExtension)
          end.new
        end

        it {
          should respond_to :__honeybadger_bindings_stack
        }

        describe "#set_backtrace" do
          context "call stack does not match current file" do
            it "changes the bindings stack" do
              expect { subject.set_backtrace(['foo.rb:1']) }.to change(subject, :__honeybadger_bindings_stack).from([])
            end
          end

          context "call stack includes current file" do
            before do
              allow(subject).to receive(:caller).and_return(["#{File.expand_path('../../../../../lib/honeybadger/plugins/local_variables.rb', __FILE__)}:1"])
            end

            it "does not change the bindings stack" do
              expect { subject.set_backtrace(['foo.rb:1']) }.not_to change(subject, :__honeybadger_bindings_stack).from([])
            end
          end

          context "call stack includes a non-matching line" do
            before do
              allow(subject).to receive(:caller).and_return(['(foo)'])
            end

            it "skips the non-matching line" do
              expect { subject.set_backtrace(['foo.rb:1']) }.not_to raise_error
            end

            it "changes the bindings stack" do
              expect { subject.set_backtrace(['foo.rb:1']) }.to change(subject, :__honeybadger_bindings_stack).from([])
            end
          end
        end
      end
    end
  end
end
