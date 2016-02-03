require 'rails'
require 'yaml'

require 'honeybadger/util/sanitizer'
require 'honeybadger/util/request_payload'
require 'honeybadger/rack/error_notifier'
require 'honeybadger/rack/user_informer'
require 'honeybadger/rack/user_feedback'

module Honeybadger
  module Init
    module Rails
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load 'honeybadger/tasks.rb'
        end

        initializer 'honeybadger.install' do
          config = Config.new(local_config)
          if Honeybadger.start(config)
            if config.feature?(:notices) && config[:'exceptions.enabled']
              ::Rails.application.config.middleware.tap do |middleware|
                middleware.insert(0, Honeybadger::Rack::ErrorNotifier, config)
                middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserInformer, config) if config[:'user_informer.enabled']
                middleware.insert_before(Honeybadger::Rack::ErrorNotifier, Honeybadger::Rack::UserFeedback, config) if config[:'feedback.enabled']
              end
            end

            if config.traces?
              ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |name, started, finished, id, data|
                Trace.create(id)
              end

              ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                Trace.current.add_query(event) if Trace.current and event.name != 'SCHEMA'
              end

              ActiveSupport::Notifications.subscribe(/^render_(template|partial|action|collection)\.action_view/) do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                Trace.current.add(event) if Trace.current
              end

              ActiveSupport::Notifications.subscribe('net_http.request') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                Trace.current.add(event) if Trace.current
              end

              ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                if Trace.current && event.payload[:controller] && event.payload[:action]
                  payload = { source: 'web' }
                  payload[:path] = Util::Sanitizer.new(filters: config.params_filters).filter_url(event.payload[:path]) if event.payload[:path]
                  payload[:request] = request_data(event, config)
                  Trace.current.complete(event, payload)
                end
              end
            end

            if config.metrics?
              ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)
                status = event.payload[:exception] ? 500 : event.payload[:status]
                Agent.timing("app.request.#{status}", event.duration)
              end
            end
          end
        end

        private

        def local_config
          {
            :root           => ::Rails.root.to_s,
            :env            => ::Rails.env,
            :'config.path'  => ::Rails.root.join('config', 'honeybadger.yml'),
            :logger         => Logging::FormattedLogger.new(::Rails.logger),
            :framework      => :rails
          }
        end

        def request_data(event, config)
          h = {
            url: event.payload[:path],
            component: event.payload[:controller],
            action: event.payload[:action],
            params: event.payload[:params]
          }
          h.merge!(config.request_hash)
          h.delete_if {|k,v| config.excluded_request_keys.include?(k) }
          h[:sanitizer] = Util::Sanitizer.new(filters: config.params_filters)
          Util::RequestPayload.build(h).update({
            context: context_data
          })
        end

        def context_data
          if Thread.current[:__honeybadger_context]
            Util::Sanitizer.new.sanitize(Thread.current[:__honeybadger_context])
          end
        end
      end
    end
  end
end
