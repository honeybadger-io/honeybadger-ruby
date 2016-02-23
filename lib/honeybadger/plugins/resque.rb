require 'honeybadger/plugin'
require 'honeybadger'

module Honeybadger
  module Plugins
    module Resque
      module Extension
        def around_perform_with_honeybadger(*args)
          Honeybadger.flush do
            begin
              Honeybadger::Trace.instrument("#{self.name}#perform", { source: 'resque', class: self.name }) do
                yield
              end
            rescue Exception => e
              Honeybadger.notify(e, parameters: { job_arguments: args }) if send_exception?(e, args)
              raise e
            end
          end
        ensure
          Honeybadger.context.clear!
        end

        def send_exception?(e, args)
          return true unless respond_to?(:retry_criteria_valid?)
          return true if ::Honeybadger::Agent.config[:'resque.resque_retry.send_exceptions_when_retrying']

          !retry_criteria_valid?(e)
        rescue => e
          Honeybadger.notify(e, parameters: { job_arguments: args })
          raise e
        end
      end

      module Installer
        def self.included(base)
          base.send(:alias_method, :payload_class_without_honeybadger, :payload_class)
          base.send(:alias_method, :payload_class, :payload_class_with_honeybadger)
        end

        def payload_class_with_honeybadger
          payload_class_without_honeybadger.tap do |klass|
            unless klass.respond_to?(:around_perform_with_honeybadger)
              klass.instance_eval do
                extend(::Honeybadger::Plugins::Resque::Extension)
              end
            end
          end
        end
      end

      Plugin.register do
        requirement { defined?(::Resque::Job) }

        requirement do
          if resque_honeybadger = defined?(::Resque::Failure::Honeybadger)
            logger.warn("Support for Resque has been moved " \
                        "to the honeybadger gem. Please remove " \
                        "resque-honeybadger from your " \
                        "Gemfile.")
          end
          !resque_honeybadger
        end

        execution do
          ::Resque::Job.send(:include, Installer)
          ::Resque.after_fork do |job|
            Honeybadger::Agent.fork
          end
        end
      end
    end
  end
end
