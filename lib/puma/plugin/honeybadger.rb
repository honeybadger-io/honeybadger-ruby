require 'honeybadger/instrumentation_helper'

module Honeybadger
  class PumaPlugin
    include Honeybadger::InstrumentationHelper

    STATS_KEYS = %i(pool_capacity max_threads requests_count backlog running).freeze

    ::Puma::Plugin.create do
      def start(launcher)
        puma_plugin = ::Honeybadger::PumaPlugin.new
        in_background do
          loop do
            puma_plugin.record
            sleep 1
          end
        end
      end
    end

    def record
      metric_source 'puma'

      stats = ::Puma.stats rescue {}
      stats = stats.is_a?(Hash) ? stats : JSON.parse(stats, symbolize_names: true)

      if stats[:worker_status].is_a?(Array)
        stats[:worker_status].each do |worker_data|
          context = { worker: worker_data[:index] }
          record_puma_stats(worker_data[:last_status], context)
        end
      else
        record_puma_stats(stats)
      end
    end

    def record_puma_stats(stats, context={})
      STATS_KEYS.each do |stat|
        gauge stat, context, ->{ stats[stat] } if stats[stat]
      end
    end
  end
end
