require 'honeybadger/instrumentation_helper'
require 'honeybadger/plugin'

module Honeybadger
  module Plugins
    module Autotuner
      Plugin.register :autotuner do
        requirement { config.load_plugin_insights?(:autotuner) && defined?(::Autotuner) }

        execution do
          singleton_class.include(Honeybadger::InstrumentationHelper)

          ::Autotuner.enabled = true

          ::Autotuner.reporter = proc do |report|
            Honeybadger.event("report.autotuner", report: report.to_s)
          end

          metric_source 'autotuner'

          ::Autotuner.metrics_reporter = proc do |metrics|
            metrics.each do |key, val|
              gauge key, ->{ val }
            end
          end
        end
      end
    end
  end
end
