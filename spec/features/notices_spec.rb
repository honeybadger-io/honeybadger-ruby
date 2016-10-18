REQUEST_FILE = TMP_DIR.join('features', 'request.rb').freeze

feature "error notifications" do
  scenario "when the server responds with a 403" do
    before do
      set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
      set_environment_variable('HONEYBADGER_BACKEND', 'server')
      set_environment_variable('HONEYBADGER_LOGGING_LEVEL', '0')

      write_file('test.rb', <<-CONTENTS)
      require 'honeybadger'
      require 'webmock'

      WebMock.enable!

      WebMock::API.stub_request(:post, 'https://api.honeybadger.io/v1/notices').to_return(status: 403, body: '{"error":"unauthorized"}', headers: { 'Content-Type' => 'application/json' })
      WebMock::API.stub_request(:post, 'https://api.honeybadger.io/v1/ping').to_return(body: %({"features":{"notices":true,"feedback":true}, "limit":null}), headers: { 'Content-Type' => 'application/json' })

      Honeybadger.start
      begin
        raise RuntimeError, "Yo' app is broke."
      rescue => e
        Honeybadger.notify(e)
      end
      CONTENTS
    end

    it "stops the agent" do
      expect(run('ruby test.rb')).to be_successfully_executed
      expect(all_output).to match(/unauthorized/i)
    end
  end

  scenario "an unhandled exception occurs in a Sinatra app", framework: :sinatra do
    let(:url) { 'http://example.com:123/test/failure?param=value' }

    before do
      set_environment_variable('HONEYBADGER_LOGGING_LEVEL', '0')
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
      expect(run('ruby request.rb')).to be_successfully_executed
      assert_notification('error' => {'class' => 'RuntimeError', 'message' => 'RuntimeError: Sinatra has left the building'}, 'request' => {'url' => url})
    end
  end
end
