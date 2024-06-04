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
            Honeybadger.event('perform.sidekiq', context)

            metric_source 'sidekiq'
            histogram 'perform', { bins: [30, 60, 120, 300, 1800, 3600, 21_600] }.merge(context.slice(:worker, :queue, :duration))
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

          Honeybadger.event('enqueue.sidekiq', context)

          yield
        end
      end

      Plugin.register :sidekiq do
        leader_checker = nil

        requirement { defined?(::Sidekiq) }

        execution do
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

          if config.load_plugin_insights?(:sidekiq)
            require "sidekiq"
            require "sidekiq/api"
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

            ::Sidekiq.configure_server do |config|
              config.server_middleware { |chain| chain.add(ServerMiddlewareInstrumentation) }
              config.client_middleware { |chain| chain.add(ClientMiddlewareInstrumentation) }
              config.on(:startup) do
                leader_checker = SidekiqClusterCollectionChecker.new(config)
              end
            end

            ::Sidekiq.configure_client do |config|
              config.client_middleware { |chain| chain.add(ClientMiddlewareInstrumentation) }
            end
          end
        end

        collect do
          if config.cluster_collection?(:sidekiq) && (leader_checker.nil? || leader_checker.collect?)
            metric_source 'sidekiq'

            stats = ::Sidekiq::Stats.new

            gauge 'active_workers', ->{ stats.workers_size }
            gauge 'active_processes', ->{ stats.processes_size }
            gauge 'jobs_processed', ->{ stats.processed }
            gauge 'jobs_failed', ->{ stats.failed }
            gauge 'jobs_scheduled', ->{ stats.scheduled_size }
            gauge 'jobs_enqueued', ->{ stats.enqueued }
            gauge 'jobs_dead', ->{ stats.dead_size }
            gauge 'jobs_retry', ->{ stats.retry_size }

            ::Sidekiq::Queue.all.each do |queue|
              gauge 'queue_latency', { queue: queue.name }, ->{ (queue.latency * 1000).ceil }
              gauge 'queue_depth', { queue: queue.name }, ->{ queue.size }
            end

            Hash.new(0).tap do |busy_counts|
              ::Sidekiq::Workers.new.each do |_pid, _tid, work|
                payload = work.respond_to?(:payload) ? work.payload : work["payload"]
                payload = JSON.parse(payload) if payload.is_a?(String)
                busy_counts[payload["queue"]] += 1
              end
            end.each do |queue_name, busy_count|
              gauge 'queue_busy', { queue: queue_name }, ->{ busy_count }
            end

            processes = ::Sidekiq::ProcessSet.new.to_enum(:each).to_a
            gauge 'capacity', ->{ processes.map { |process| process["concurrency"] }.sum }

            process_utilizations = processes.map do |process|
              next unless process["concurrency"].to_f > 0
              process["busy"] / process["concurrency"].to_f
            end.compact

            if process_utilizations.any?
              utilization = process_utilizations.sum / process_utilizations.length.to_f
              gauge 'utilization', ->{ utilization }
            end
          end
        end
      end
    end
  end
end
