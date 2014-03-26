module Honeybadger
  module ExceptionExtensions
    module Bindings
      def self.included(base)
        base.send(:alias_method, :set_backtrace_without_honeybadger, :set_backtrace)
        base.send(:alias_method, :set_backtrace, :set_backtrace_with_honeybadger)
      end

      def set_backtrace_with_honeybadger(*args, &block)
        if caller.none? { |loc| loc.match(Honeybadger::Backtrace::Line::INPUT_FORMAT)[:path] == __FILE__ }
          @__honeybadger_bindings_stack = binding.callers.drop(1)
        end

        set_backtrace_without_honeybadger(*args, &block)
      end

      def __honeybadger_bindings_stack
        @__honeybadger_bindings_stack || []
      end
    end

    module NullBindings
      def __honeybadger_bindings_stack
        []
      end
    end
  end
end

begin
  require 'binding_of_caller'
  Exception.send(:include, Honeybadger::ExceptionExtensions::Bindings)
rescue LoadError
  Exception.send(:include, Honeybadger::ExceptionExtensions::NullBindings)
end
