module Honeybadger
  module Integrations
    module LocalVariables
      module ExceptionExtension
        def self.included(base)
          base.send(:alias_method, :set_backtrace_without_honeybadger, :set_backtrace)
          base.send(:alias_method, :set_backtrace, :set_backtrace_with_honeybadger)
        end

        def set_backtrace_with_honeybadger(*args, &block)
          if caller.none? { |loc| loc.match(::Honeybadger::Backtrace::Line::INPUT_FORMAT) && Regexp.last_match(1) == __FILE__ }
            @__honeybadger_bindings_stack = binding.callers.drop(1)
          end

          set_backtrace_without_honeybadger(*args, &block)
        end

        def __honeybadger_bindings_stack
          @__honeybadger_bindings_stack || []
        end
      end

      Dependency.register do
        requirement { ::Honeybadger.configuration.send_local_variables }
        requirement { defined?(::BindingOfCaller) }
        requirement { !::Exception.included_modules.include?(ExceptionExtension) }

        injection { Honeybadger.write_verbose_log('Installing local variables integration') }

        injection do
          ::Exception.send(:include, ExceptionExtension)
        end
      end
    end
  end
end
