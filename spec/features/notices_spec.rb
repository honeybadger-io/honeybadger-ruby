REQUEST_FILE = TMP_DIR.join('features', 'request.rb').freeze

feature "error notifications" do
  scenario "when the server responds with a 403" do
    before do
      set_env('HONEYBADGER_API_KEY', 'asdf')
      set_env('HONEYBADGER_BACKEND', 'server')
      set_env('HONEYBADGER_LOGGING_LEVEL', '0')

      write_file('test.rb', <<-CONTENTS)
      require 'honeybadger'
      require 'sham_rack'

      ShamRack.at("api.honeybadger.io", 443).stub.tap do |app|
        app.register_resource("/v1/notices", "403 Forbidden", "application/json", 403)
        app.register_resource("/v1/ping", %({"features":{"notices":true,"feedback":true}, "limit":null}), "application/json")
      end

      Honeybadger.start
      begin
        raise RuntimeError, "Yo' app is broke."
      rescue => e
        Honeybadger.notify(e)
      end
      CONTENTS
    end

    it "stops the agent" do
      expect(assert_cmd('ruby test.rb')).to run_successfully
      expect(all_output).to match(/worker shutting down \(unauthorized\)/i)
    end
  end

  scenario "an unhandled exception occurs in a Rails controller", framework: :rails do
    let(:url) { 'http://example.com:123/test/index?param=value' }

    before do
      set_env('SECRET_KEY_BASE', 'sekret')
      set_env('HONEYBADGER_API_KEY', 'asdf')
      set_env('HONEYBADGER_LOGGING_LEVEL', '0')
    end

    before do
      define_action('TestController#index', <<-ACTION)
      session[:value] = "test"
      raise RuntimeError, "some message"
      ACTION

      define_route('/test/index', 'test#index')
    end

    it "reports the exception to Honeybadger" do
      perform_request(url)
      assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: some message'}, 'request' => {'url' => url})
    end
  end

  scenario "an unhandled exception occurs in a Sinatra app", framework: :sinatra do
    let(:url) { 'http://example.com:123/test/failure?param=value' }

    before do
      set_env('HONEYBADGER_LOGGING_LEVEL', '0')
    end

    before do
      FileUtils.cp(FIXTURES_PATH.join('sinatra.rb'), REQUEST_FILE)
      File.open(REQUEST_FILE, 'a') do |file|
        file.puts "env = Rack::MockRequest.env_for(#{url.inspect})"
        file.puts 'status, headers, body = app.call(env)'
        file.puts 'puts "HTTP #{status}"'
        file.puts 'headers.each { |key, value| puts "#{key}: #{value}"}'
        file.puts 'body.each { |part| print part }'
      end
    end

    it "reports the exception to Honeybadger" do
      assert_cmd('ruby request.rb')
      assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Sinatra has left the building'}, 'request' => {'url' => url})
    end
  end
end
