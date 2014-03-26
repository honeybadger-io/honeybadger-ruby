module Honeybadger
  module Rack
    class UserInformer
      def initialize(app)
        @app = app
      end

      def replacement(with)
        Honeybadger.configuration.user_information.gsub(/\{\{\s*error_id\s*\}\}/, with.to_s)
      end

      def call(env)
        status, headers, body = @app.call(env)
        if env['honeybadger.error_id'] && Honeybadger.configuration.user_information
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
    end
  end
end
