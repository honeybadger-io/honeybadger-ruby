require 'honeybadger/plugin'
require 'honeybadger/notification_subscriber'

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
          # We only report handled errors (`Rails.error.handle`)
          # Unhandled errors will be caught by our integrations (eg middleware),
          # which have richer context than the Rails error reporter
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

      Plugin.register :rails do
        requirement { defined?(::Rails.application) && ::Rails.application }

        execution do
          if config.load_plugin_insights?(:rails)
            ::ActiveSupport::Notifications.subscribe(/(process_action|send_file|redirect_to|halted_callback|unpermitted_parameters)\.action_controller/, Honeybadger::ActionControllerSubscriber.new)
            ::ActiveSupport::Notifications.subscribe(/(write_fragment|read_fragment|expire_fragment|exist_fragment\?)\.action_controller/, Honeybadger::ActionControllerCacheSubscriber.new)
            ::ActiveSupport::Notifications.subscribe(/cache_(read|read_multi|generate|fetch_hit|write|write_multi|increment|decrement|delete|delete_multi|cleanup|prune|exist\?)\.active_support/, Honeybadger::ActiveSupportCacheSubscriber.new)
            ::ActiveSupport::Notifications.subscribe(/^render_(template|partial|collection)\.action_view/, Honeybadger::ActionViewSubscriber.new)
            ::ActiveSupport::Notifications.subscribe("sql.active_record", Honeybadger::ActiveRecordSubscriber.new)
            ::ActiveSupport::Notifications.subscribe("process.action_mailer", Honeybadger::ActionMailerSubscriber.new)
            ::ActiveSupport::Notifications.subscribe(/(service_upload|service_download)\.active_storage/, Honeybadger::ActiveStorageSubscriber.new)
          end
        end
      end
    end
  end
end
