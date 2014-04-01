require 'spec_helper'

describe Exception, :unless => defined?(BindingOfCaller) do
  should { respond_to :__honeybadger_bindings_stack }
  its(:__honeybadger_bindings_stack) { should eq([]) }
end

describe Exception, :if => defined?(BindingOfCaller) do
  describe "#set_backtrace" do
    context "call stack does not match current file" do
      it "changes the bindings stack" do
        expect { subject.set_backtrace(['foo.rb:1']) }.to change(subject, :__honeybadger_bindings_stack).from([])
      end
    end

    context "call stack includes current file" do
      before do
        subject.stub(:caller).and_return(["#{File.expand_path('../../../lib/honeybadger/exception_extensions.rb', __FILE__)}:1"])
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
