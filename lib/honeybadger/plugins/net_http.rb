require 'net/http'
require 'honeybadger/plugin'
require 'honeybadger/instrumentation'
require 'resolv'

module Honeybadger
  module Plugins
    module Net
      module HTTP
        @@hb_config = ::Honeybadger.config

        def self.set_hb_config(config)
          @@hb_config = config
        end

        def request(request_data, body = nil, &block)
          return super unless started?
          return super if hb?

          Honeybadger.instrumentation.monotonic_timer { super }.tap do |duration, response_data|
            context = {
              duration: duration,
              method: request_data.method,
              status: response_data.code.to_i
            }.merge(parsed_uri_data(request_data))

            if @@hb_config.load_plugin_insights_events?(:net_http)
              Honeybadger.event('request.net_http', context)
            end

            if @@hb_config.load_plugin_insights_metrics?(:net_http)
              context.delete(:url)
              Honeybadger.gauge('duration.request', context.merge(metric_source: 'net_http'))
            end
          end[1] # return the response data only
        end

        def hb?
          address.to_s[/#{@@hb_config[:'connection.host'].to_s}/]
        end

        def parsed_uri_data(request_data)
          uri = request_data.uri || build_uri(request_data)
          {}.tap do |uri_data|
            uri_data[:host] = uri.host
            uri_data[:url] = uri.to_s if @@hb_config[:'net_http.insights.full_url']
          end
        end

        def build_uri(request_data)
          hostname = (address[/#{Resolv::IPv6::Regex}/]) ? "[#{address}]" : address
          URI.parse("#{use_ssl? ? 'https' : 'http'}://#{hostname}#{request_data.path}")
        end

        Plugin.register :net_http do
          requirement { config.load_plugin_insights?(:net_http) }

          execution do
            Honeybadger::Plugins::Net::HTTP.set_hb_config(config)
            ::Net::HTTP.send(:prepend, Honeybadger::Plugins::Net::HTTP)
          end
        end
      end
    end
  end
end
