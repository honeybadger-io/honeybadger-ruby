require 'net/http'
require 'honeybadger/plugin'
require 'honeybadger/instrumentation'
require 'resolv'

module Honeybadger
  module Plugins
    module Net
      module HTTP
        def request(request_data, body = nil, &block)
          return super unless started?
          return super if hb?

          Honeybadger.instrumentation.monotonic_timer { super }.tap do |duration, response_data|
            context = {
              duration: duration,
              method: request_data.method,
              status: response_data.code.to_i
            }.merge(parsed_uri_data(request_data))

            Honeybadger.event('request.net_http', context)
          end[1] # return the response data only
        end

        def hb?
          address.to_s[/#{Honeybadger.config[:'connection.host'].to_s}/]
        end

        def parsed_uri_data(request_data)
          uri = request_data.uri || build_uri(request_data)
          {}.tap do |uri_data|
            uri_data[:host] = uri.host
            uri_data[:url] = uri.to_s if Honeybadger.config[:'net_http.insights.full_url']
          end
        end

        def build_uri(request_data)
          hostname = (address[/#{Resolv::IPv6::Regex}/]) ? "[#{address}]" : address
          URI.parse("#{use_ssl? ? 'https' : 'http'}://#{hostname}#{request_data.path}")
        end

        Plugin.register :net_http do
          requirement { config.load_plugin_insights?(:net_http) }

          execution do
            ::Net::HTTP.send(:prepend, Honeybadger::Plugins::Net::HTTP)
          end
        end
      end
    end
  end
end
