require 'honeybadger/instrumentation_helper'
require 'honeybadger/plugin'
require 'honeybadger/ruby'

module Honeybadger
  module Plugins
    module Sidekiq
      class Middleware
        def call(_worker, _msg, _queue)
          Honeybadger.clear!
          yield
        end
      end

      class ServerMiddlewareInstrumentation
        include Honeybadger::InstrumentationHelper

        def call(worker, msg, queue, &block)
          if msg["wrapped"]
            context = {
              jid: msg["jid"],
              worker: msg["wrapped"],
              queue: queue
            }
          else
            context = {
              jid: msg["jid"],
              worker: msg["class"],
              queue: queue
            }
          end

          begin
            duration = Honeybadger.instrumentation.monotonic_timer { block.call }[0]
            status = 'success'
          rescue Exception => e
            status = 'failure'
            raise
          ensure
            context.merge!(duration: duration, status: status)
            if Honeybadger.config.load_plugin_insights_events?(:sidekiq)
              Honeybadger.event('perform.sidekiq', context)
            end

            if Honeybadger.config.load_plugin_insights_metrics?(:sidekiq)
              metric_source 'sidekiq'
              gauge 'perform', context.slice(:worker, :queue, :duration)
            end
          end
        end
      end

      class ClientMiddlewareInstrumentation
        include Honeybadger::InstrumentationHelper

        def call(worker, msg, queue, _redis)
          context = {
            worker: msg["wrapped"] || msg["class"],
            queue: queue
          }

          if Honeybadger.config.load_plugin_insights_events?(:sidekiq)
            Honeybadger.event('enqueue.sidekiq', context)
          end

          yield
        end
      end

      Plugin.register :sidekiq do
        leader_checker = nil

        requirement { defined?(::Sidekiq) }

        execution do
          if Honeybadger.config[:'exceptions.enabled']
            ::Sidekiq.configure_server do |sidekiq|
              sidekiq.server_middleware do |chain|
                chain.prepend Middleware
              end
            end

            if defined?(::Sidekiq::VERSION) && ::Sidekiq::VERSION > '3'
              ::Sidekiq.configure_server do |sidekiq|

                sidekiq_default_configuration = (::Sidekiq::VERSION > '7') ?
                  ::Sidekiq.default_configuration : Class.new

                sidekiq.error_handlers << lambda { |ex, sidekiq_params, sidekiq_config = sidekiq_default_configuration|
                  params = sidekiq_params.dup
                  if defined?(::Sidekiq::Config)
                    if params[:_config].is_a?(::Sidekiq::Config) # Sidekiq > 6 and < 7.1.5
                      params[:_config] = params[:_config].instance_variable_get(:@options)
                    else # Sidekiq >= 7.1.5
                      params[:_config] = sidekiq_config.instance_variable_get(:@options)
                    end
                  end

                  job = params[:job] || params

                  job_retry = job['retry'.freeze]

                  if (threshold = config[:'sidekiq.attempt_threshold'].to_i) > 0 && job_retry
                    # We calculate the job attempts to determine the need to
                    # skip. Sidekiq's first job execution will have nil for the
                    # 'retry_count' job key. The first retry will have 0 set for
                    # the 'retry_count' key, incrementing on each execution
                    # afterwards.
                    retry_count = job['retry_count'.freeze]
                    attempt = retry_count ? retry_count + 1 : 0

                    max_retries = (::Sidekiq::VERSION > '7') ?
                      ::Sidekiq.default_configuration[:max_retries] : sidekiq.options[:max_retries]
                    # Ensure we account for modified max_retries setting
                    default_max_retry_attempts = defined?(::Sidekiq::JobRetry::DEFAULT_MAX_RETRY_ATTEMPTS) ? ::Sidekiq::JobRetry::DEFAULT_MAX_RETRY_ATTEMPTS : 25
                    retry_limit = job_retry == true ? (max_retries || default_max_retry_attempts) : job_retry.to_i

                    limit = [retry_limit, threshold].min

                    return if attempt < limit
                  end

                  opts = { parameters: params }
                  if config[:'sidekiq.use_component']
                    opts[:component] = job['wrapped'.freeze] || job['class'.freeze]
                    opts[:action] = 'perform' if opts[:component]
                  end

                  Honeybadger.notify(ex, opts)
                }
              end
            end
          end

          if config.load_plugin_insights?(:sidekiq)
            require "sidekiq"
            require "sidekiq/api"

            if Gem::Version.new(::Sidekiq::VERSION) >= Gem::Version.new('6.5')
              require "sidekiq/component"

              class SidekiqClusterCollectionChecker
                include ::Sidekiq::Component
                def initialize(config)
                  @config = config
                end

                def collect?
                  return true unless defined?(::Sidekiq::Enterprise)
                  leader?
                end
              end
            end

            ::Sidekiq.configure_server do |config|
              config.server_middleware { |chain| chain.add(ServerMiddlewareInstrumentation) }
              config.client_middleware { |chain| chain.add(ClientMiddlewareInstrumentation) }

              if defined?(SidekiqClusterCollectionChecker)
                config.on(:startup) do
                  leader_checker = SidekiqClusterCollectionChecker.new(config)
                end
              end
            end

            ::Sidekiq.configure_client do |config|
              config.client_middleware { |chain| chain.add(ClientMiddlewareInstrumentation) }
            end
          end
        end

        collect_sidekiq_stats = -> do
          stats = ::Sidekiq::Stats.new
          data = stats.as_json
          data[:queues] = {}

          ::Sidekiq::Queue.all.each do |queue|
            data[:queues][queue.name] ||= {}
            data[:queues][queue.name][:latency] = (queue.latency * 1000).ceil
            data[:queues][queue.name][:depth] = queue.size
          end

          Hash.new(0).tap do |busy_counts|
            ::Sidekiq::Workers.new.each do |_pid, _tid, work|
              payload = work.respond_to?(:payload) ? work.payload : work["payload"]
              payload = JSON.parse(payload) if payload.is_a?(String)
              busy_counts[payload["queue"]] += 1
            end
          end.each do |queue_name, busy_count|
            data[:queues][queue_name] ||= {}
            data[:queues][queue_name][:busy] = busy_count
          end

          processes = ::Sidekiq::ProcessSet.new.to_enum(:each).to_a
          data[:capacity] = processes.map { |process| process["concurrency"] }.sum

          process_utilizations = processes.map do |process|
            next unless process["concurrency"].to_f > 0
            process["busy"] / process["concurrency"].to_f
          end.compact

          if process_utilizations.any?
            utilization = process_utilizations.sum / process_utilizations.length.to_f
            data[:utilization] = utilization
          end

          data
        end

        collect do
          if config.cluster_collection?(:sidekiq) && (leader_checker.nil? || leader_checker.collect?)
            stats = collect_sidekiq_stats.call

            if Honeybadger.config.load_plugin_insights_events?(:sidekiq)
              Honeybadger.event('stats.sidekiq', stats.except('stats').merge(stats['stats']))
            end

            if Honeybadger.config.load_plugin_insights_metrics?(:sidekiq)
              metric_source 'sidekiq'

              stats['stats'].each do |name, value|
                gauge name, value: value
              end

              stats[:queues].each do |queue_name, data|
                data.each do |key, value|
                  gauge "queue_#{key}", queue: queue_name, value: value
                end
              end

              gauge 'capacity', value: stats[:capacity] if stats[:capacity]
              gauge 'utilization', value: stats[:utilization] if stats[:utilization]
            end
          end
        end
      end
    end
  end
end
