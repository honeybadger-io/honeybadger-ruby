require 'spec_helper'

begin
  require 'active_support'
  require 'action_controller'
  require 'action_controller/test_process'
  require 'honeybadger/rails'

  describe Honeybadger::Rails::ActionControllerCatcher do
    include DefinesConstants

    before(:each) do
      reset_config
      Honeybadger.sender = CollectingSender.new
      define_constant('RAILS_ROOT', '/path/to/rails/root')
    end

    def ignore(exception_class)
      Honeybadger.configuration.ignore << exception_class
    end

    def build_controller_class(&definition)
      Class.new(ActionController::Base).tap do |klass|
        klass.__send__(:include, Honeybadger::Rails::ActionControllerCatcher)
        klass.class_eval(&definition) if definition
        define_constant('HoneybadgerTestController', klass)
      end
    end

    def assert_sent_hash(hash, &block)
      hash.each do |key, value|
        next if key.match(/^honeybadger\./) # We added this key.

        new_block = Proc.new {
          block.call(last_sent_notice_payload)[key]
        }

        if value.respond_to?(:to_hash)
          assert_sent_hash(value.to_hash, &new_block)
        else
          assert_sent_element(value, &new_block)
        end
      end
    end

    def assert_sent_element(value, &block)
      expect(yield(last_sent_notice_payload)).to eq stringify_array_elements(value)
    end

    def stringify_array_elements(data)
      if data.is_a?(Array)
        data.collect do |value|
          stringify_array_elements(value)
        end
      elsif Honeybadger::Payload::OBJECT_WHITELIST.any? {|c| data.kind_of?(c) }
        data
      else
        data.to_s
      end
    end

    def assert_sent_request_info_for(request)
      params = request.parameters.to_hash
      assert_sent_hash(params) { |h| h['request']['params'] }
      assert_sent_element(params['controller']) { |h| h['request']['component'] }
      assert_sent_element(params['action']) { |h| h['request']['action'] }
      assert_sent_element(url_from_request(request)) { |h| h['request']['url'] }
      assert_sent_hash(request.env.reject {|k,_| k == 'QUERY_STRING' || !k.match(/\A[A-Z_]+\Z/) }) { |h| h['request']['cgi_data'] }
    end

    def url_from_request(request)
      url = "#{request.protocol}#{request.host}"

      unless [80, 443].include?(request.port)
        url << ":#{request.port}"
      end

      url << request.request_uri
      url
    end

    def sender
      Honeybadger.sender
    end

    def last_sent_notice_json
      sender.collected.last
    end

    def last_sent_notice_payload
      expect(last_sent_notice_json).to_not be_nil
      JSON.parse(last_sent_notice_json)
    end

    def build_controller(opts = {}, &action)
      klass = build_controller_class do
        cattr_accessor :local
        define_method(:index, &action)
        def local_request?
          local
        end
      end

      if opts[:filters]
        klass.filter_parameter_logging(*opts[:filters])
      end

      klass.consider_all_requests_local = opts[:all_local]
      klass.local                       = opts[:local]
      controller = klass.new
      controller.stub(:rescue_action_in_public_without_honeybadger)
      controller
    end

    def process_action(opts = {}, &action)
      opts[:request]  ||= ActionController::TestRequest.new
      opts[:response] ||= ActionController::TestResponse.new

      controller = opts[:controller] || build_controller(opts, &action)

      if opts[:user_agent]
        if opts[:request].respond_to?(:user_agent=)
          opts[:request].user_agent = opts[:user_agent]
        else
          opts[:request].env["HTTP_USER_AGENT"] = opts[:user_agent]
        end
      end

      if opts[:port]
        opts[:request].port = opts[:port]
      end

      opts[:request].query_parameters = opts[:request].query_parameters.merge(opts[:params] || {})
      opts[:request].session = if opts.include?(:session) && opts[:session].nil?
                                 nil
                               else
                                 ActionController::TestSession.new(opts[:session] || {})
                               end
      # Prevents request.fullpath from crashing Rails in tests
      opts[:request].env['REQUEST_URI'] = opts[:request].request_uri

      controller.process(opts[:request], opts[:response])
      controller
    end

    def process_action_with_manual_notification(args = {})
      process_action(args) do
        notify_honeybadger(:error_message => 'fail')
        # Rails will raise a template error if we don't render something
        render :nothing => true
      end
    end

    def process_action_with_automatic_notification(args = {})
      process_action(args) { raise "Hello" }
    end

    it "delivers notices from exceptions raised in public requests" do
      process_action_with_automatic_notification
      assert_caught_and_sent
    end

    it "not deliver notices from exceptions in local requests" do
      process_action_with_automatic_notification(:local => true)
      assert_caught_and_not_sent
    end

    it "not deliver notices from exceptions when all requests are local" do
      process_action_with_automatic_notification(:all_local => true)
      assert_caught_and_not_sent
    end

    it "not deliver notices from actions that don't raise" do
      controller = process_action { render :text => 'Hello' }
      assert_caught_and_not_sent
      expect(controller.response.body).to eq 'Hello'
    end

    it "not deliver ignored exceptions raised by actions" do
      ignore(RuntimeError)
      process_action_with_automatic_notification
      assert_caught_and_not_sent
    end

    it "deliver ignored exception raised manually" do
      ignore(RuntimeError)
      process_action_with_manual_notification
      assert_caught_and_sent
    end

    it "deliver manually sent notices in public requests" do
      process_action_with_manual_notification
      assert_caught_and_sent
    end

    it "not deliver manually sent notices in local requests" do
      process_action_with_manual_notification(:local => true)
      assert_caught_and_not_sent
    end

    it "not deliver manually sent notices when all requests are local" do
      process_action_with_manual_notification(:all_local => true)
      assert_caught_and_not_sent
    end

    it "continue with default behavior after delivering an exception" do
      controller = build_controller(:public => true) { raise 'cobras!' }
      controller.should_receive(:rescue_action_in_public_without_honeybadger)
      process_action(:controller => controller)
    end

    it "not create actions from Honeybadger methods" do
      build_controller_class.new
      expect(Honeybadger::Rails::ActionControllerCatcher.instance_methods).to be_empty
    end

    it "ignore exceptions when user agent is being ignored by regular expression" do
      Honeybadger.configuration.ignore_user_agent_only = [/Ignored/]
      process_action_with_automatic_notification(:user_agent => 'ShouldBeIgnored')
      assert_caught_and_not_sent
    end

    it "ignore exceptions when user agent is being ignored by string" do
      Honeybadger.configuration.ignore_user_agent_only = ['IgnoredUserAgent']
      process_action_with_automatic_notification(:user_agent => 'IgnoredUserAgent')
      assert_caught_and_not_sent
    end

    it "not ignore exceptions when user agent is not being ignored" do
      Honeybadger.configuration.ignore_user_agent_only = ['IgnoredUserAgent']
      process_action_with_automatic_notification(:user_agent => 'NonIgnoredAgent')
      assert_caught_and_sent
    end

    it "send session data for manual notifications" do
      data = { 'one' => 'two' }
      process_action_with_manual_notification(:session => data)
      assert_sent_hash(data) { |h| h['request']['session'] }
    end

    it "send session data for automatic notification" do
      data = { 'one' => 'two' }
      process_action_with_automatic_notification(:session => data)
      assert_sent_hash(data) { |h| h['request']['session'] }
    end

    it "fails gracefully when session isn nil" do
      process_action_with_automatic_notification(:session => nil)
      assert_sent_hash({}) { |h| h['request']['session'] }
    end

    it "send request data for manual notification" do
      params = { 'controller' => "honeybadger_test", 'action' => "index" }
      controller = process_action_with_manual_notification(:params => params)
      assert_sent_request_info_for controller.request
    end

    it "send request data for manual notification with non-standard port" do
      params = { 'controller' => "honeybadger_test", 'action' => "index" }
      controller = process_action_with_manual_notification(:params => params, :port => 81)
      assert_sent_request_info_for controller.request
    end

    it "send request data for automatic notification" do
      params = { 'controller' => "honeybadger_test", 'action' => "index" }
      controller = process_action_with_automatic_notification(:params => params)
      assert_sent_request_info_for controller.request
    end

    it "send request data for automatic notification with non-standard port" do
      params = { 'controller' => "honeybadger_test", 'action' => "index" }
      controller = process_action_with_automatic_notification(:params => params, :port => 81)
      assert_sent_request_info_for controller.request
    end

    it "use standard rails logging filters on params and session and env" do
      filtered_params = { "abc" => "123",
                          "def" => "456",
                          "ghi" => "[FILTERED]" }
      filtered_session = { "abc" => "123",
                           "ghi" => "[FILTERED]" }
      ENV['ghi'] = 'abc'
      filtered_env = { 'ghi' => '[FILTERED]' }
      filtered_cgi = { 'REQUEST_METHOD' => '[FILTERED]' }

      process_action_with_automatic_notification(:filters => [:ghi, :request_method],
                                                 :params => { "abc" => "123",
                                                              "def" => "456",
                                                              "ghi" => "789" },
                                                              :session => { "abc" => "123",
                                                                            "ghi" => "789" })
      assert_sent_hash(filtered_params) { |h| h['request']['params'] }
      assert_sent_hash(filtered_cgi) { |h| h['request']['cgi_data'] }
      assert_sent_hash(filtered_session) { |h| h['request']['session'] }
    end

    it "call session.to_hash if available" do
      hash_data = {:key => :value}

      session = ActionController::TestSession.new
      ActionController::TestSession.stub(:new).and_return(session)
      session.stub(:to_hash).and_return(hash_data)

      session.should_receive(:to_hash)
      session.should_receive(:data).never

      process_action_with_automatic_notification
      assert_caught_and_sent
    end

    it "call session.data if session.to_hash is undefined" do
      hash_data = {:key => :value}

      session = ActionController::TestSession.new
      ActionController::TestSession.stub(:new).and_return(session)
      session.stub(:data).and_return(hash_data)
      session.stub(:respond_to?).with(:to_hash).and_return(false)

      session.should_receive(:to_hash).never
      session.should_receive(:data).at_least(1).times

      process_action_with_automatic_notification
      assert_caught_and_sent
    end
  end
rescue LoadError
  nil
end
