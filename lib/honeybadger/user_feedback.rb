require 'erb'
require 'uri'

module Honeybadger
  class UserFeedback
    TEMPLATE = File.read(File.expand_path('../templates/feedback_form.html.erb', __FILE__)).freeze

    def initialize(app)
      @app = app
    end

    def action
      config = Honeybadger.configuration
      URI.parse("#{config.protocol}://#{config.host}:#{config.port}/v1/feedback/").to_s
    rescue URI::InvalidURIError
      nil
    end

    def render_form(error_id, action = action)
      return unless action
      ERB.new(TEMPLATE).result(binding)
    end

    def enabled?
      Honeybadger.configuration.feedback && Honeybadger.configuration.features['feedback']
    end

    def call(env)
      status, headers, body = @app.call(env)
      if enabled? && env['honeybadger.error_id'] && form = render_form(env['honeybadger.error_id'])
        new_body = []
        body.each do |chunk|
          new_body << chunk.gsub("<!-- HONEYBADGER FEEDBACK -->", form)
        end
        body.close if body.respond_to?(:close)
        headers['Content-Length'] = new_body.reduce(0) { |a,e| a += e.bytesize }.to_s
        body = new_body
      end
      [status, headers, body]
    end
  end
end
