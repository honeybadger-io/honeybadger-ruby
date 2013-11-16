require 'erb'
module Honeybadger
  class UserFeedback
    TEMPLATE = File.read(File.expand_path('../templates/feedback_form.html.erb', __FILE__)).freeze

    def initialize(app)
      @app = app
    end

    def feedback_form(error_id)
      ERB.new(TEMPLATE).result(binding)
    end

    def call(env)
      status, headers, body = @app.call(env)
      if env['honeybadger.error_id']
        new_body = []
        form     = feedback_form(env['honeybadger.error_id'])
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
