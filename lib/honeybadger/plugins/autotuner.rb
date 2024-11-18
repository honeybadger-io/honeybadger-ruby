require 'honeybadger/instrumentation_helper'
require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module Autotuner
      Plugin.register :autotuner do
        requirement { config.load_plugin_insights?(:autotuner) && defined?(::Autotuner) }

        execution do
          singleton_class.include(Honeybadger::InstrumentationHelper)

          ::Autotuner.reporter = proc do |report|
            Honeybadger.event("report.autotuner", report: report.to_s)
          end

          ::Autotuner.metrics_reporter = proc do |metrics|
            if config.load_plugin_insights_events?(:autotuner)
              Honeybadger.event('stats.autotuner', metrics)
            end

            if config.load_plugin_insights_metrics?(:autotuner)
              metric_source 'autotuner'
              metrics.each do |key, val|
                gauge key, ->{ val }
              end
            end
          end
        end
      end
    end
  end
end
