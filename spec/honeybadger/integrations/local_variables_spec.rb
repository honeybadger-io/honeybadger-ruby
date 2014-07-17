require 'spec_helper'

describe "Local variables integration" do
  before do
    Honeybadger.configuration.send_local_variables = config_enabled
    Honeybadger::Dependency.inject!
  end

  subject { Exception.new }

  context "when binding_of_caller isn't installed", :unless => defined?(::BindingOfCaller) do
    let(:config_enabled) { true }
    it { should_not respond_to :__honeybadger_bindings_stack }
  end

  context "when binding_of_caller is installed", :if => defined?(::BindingOfCaller) do
    context "and disabled by configuration" do
      let(:config_enabled) { false }
      it { should_not respond_to :__honeybadger_bindings_stack }
    end

    context "and enabled by configuration" do
      let(:config_enabled) { true }

      it { should respond_to :__honeybadger_bindings_stack }

      describe "#set_backtrace" do
        context "call stack does not match current file" do
          it "changes the bindings stack" do
            expect { subject.set_backtrace(['foo.rb:1']) }.to change(subject, :__honeybadger_bindings_stack).from([])
          end
        end

        context "call stack includes current file" do
          before do
            subject.stub(:caller).and_return(["#{File.expand_path('../../../../lib/honeybadger/integrations/local_variables.rb', __FILE__)}:1"])
          end

          it "does not change the bindings stack" do
            expect { subject.set_backtrace(['foo.rb:1']) }.not_to change(subject, :__honeybadger_bindings_stack).from([])
          end
        end

        context "call stack includes a non-matching line" do
          before do
            subject.stub(:caller).and_return(['(foo)'])
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
