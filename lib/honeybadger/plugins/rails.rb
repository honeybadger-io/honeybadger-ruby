require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module Rails
      module ExceptionsCatcher
        # Adds additional Honeybadger info to Request env when an
        # exception is rendered in Rails' middleware.
        #
        # @param [Hash, ActionDispatch::Request] arg The Rack env +Hash+ in
        #   Rails 3.0-4.2. After Rails 5 +arg+ is an +ActionDispatch::Request+.
        # @param [Exception] exception The error which was rescued.
        #
        # @return The super value of the middleware's +#render_exception()+
        #   method.
        def render_exception(arg, exception, *args)
          if arg.kind_of?(::ActionDispatch::Request)
            request = arg
            env = request.env
          else
            request = ::Rack::Request.new(arg)
            env = arg
          end

          env['honeybadger.exception'] = exception
          env['honeybadger.request.url'] = request.url rescue nil

          super(arg, exception, *args)
        end
      end

      class ErrorSubscriber
        def self.report(exception, handled:, severity:, context: {}, source: nil)
          # We only report unhandled errors (`Rails.error.handle`)
          # Unhandled errors will be caught by our integrations (eg middleware), which have richer context
          return unless handled

          return if source_ignored?(source)

          tags = ["severity:#{severity}", "handled:#{handled}"]
          tags << "source:#{source}" if source
          Honeybadger.notify(exception, context: context, tags: tags)
        end

        def self.source_ignored?(source)
          source && ::Honeybadger.config[:'rails.subscriber_ignore_sources'].any? do |ignored_source|
            ignored_source.is_a?(Regexp) ? ignored_source.match?(source) : (ignored_source == source)
          end
        end
      end

      Plugin.register :rails_exceptions_catcher do
        requirement { defined?(::Rails.application) && ::Rails.application }

        execution do
          require 'rack/request'
          if defined?(::ActionDispatch::DebugExceptions)
            # Rails 3.2.x+
            ::ActionDispatch::DebugExceptions.prepend(ExceptionsCatcher)
          elsif defined?(::ActionDispatch::ShowExceptions)
            # Rails 3.0.x and 3.1.x
            ::ActionDispatch::ShowExceptions.prepend(ExceptionsCatcher)
          end

          if defined?(::ActiveSupport::ErrorReporter) # Rails 7
            ::Rails.error.subscribe(ErrorSubscriber)
          end
        end
      end
    end
  end
end
