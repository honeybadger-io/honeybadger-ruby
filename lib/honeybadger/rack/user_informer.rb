require 'forwardable'

module Honeybadger
  module Rack
    class UserInformer
      extend Forwardable

      def initialize(app, config)
        @app = app
        @config = config
      end

      def replacement(with)
        config[:'user_informer.info'].gsub(/\{\{\s*error_id\s*\}\}/, with.to_s)
      end

      def call(env)
        status, headers, body = @app.call(env)
        if env['honeybadger.error_id']
          new_body = []
          replace  = replacement(env['honeybadger.error_id'])
          body.each do |chunk|
            new_body << chunk.gsub("<!-- HONEYBADGER ERROR -->", replace)
          end
          body.close if body.respond_to?(:close)
          headers['Content-Length'] = new_body.reduce(0) { |a,e| a += e.bytesize }.to_s
          body = new_body
        end
        [status, headers, body]
      end

      private

      attr_reader :config
      def_delegator :@config, :logger
    end
  end
end
