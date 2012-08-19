require 'test_helper'
require 'rubygems'

require File.expand_path('../../../lib/honeybadger_tasks', __FILE__)
require 'fakeweb'

FakeWeb.allow_net_connect = false

class HoneybadgerTasksTest < Honeybadger::UnitTest
  def successful_response(body = "")
    response = Net::HTTPSuccess.new('1.2', '200', 'OK')
    response.stubs(:body).returns(body)
    return response
  end

  def unsuccessful_response(body = "")
    response = Net::HTTPClientError.new('1.2', '200', 'OK')
    response.stubs(:body).returns(body)
    return response
  end

  context "being quiet" do
    setup { HoneybadgerTasks.stubs(:puts) }

    context "in a configured project" do
      setup { Honeybadger.configure { |config| config.api_key = "1234123412341234" } }

      context "on deploy({})" do
        setup { @output = HoneybadgerTasks.deploy({}) }

        before_should "complain about missing rails env" do
          HoneybadgerTasks.expects(:puts).with(regexp_matches(/which environment/i))
        end

        should "return false" do
          assert !@output
        end
      end

      context "given an optional HTTP proxy and valid options" do
        setup do
          @response         = stub("response",    :body => "stub body")
          @http_proxy       = stub("proxy",       :request => @response,
                                                  :use_ssl= => nil,
                                                  :ca_file= => nil,
                                                  :verify_mode= => nil)
          @http_proxy_class = stub("proxy_class", :new => @http_proxy)
          @post             = stub("post",        :set_form_data => nil)

          @post.stubs(:[]=).with('X-API-Key', '1234123412341234').returns(true)

          Net::HTTP.expects(:Proxy).
            with(Honeybadger.configuration.proxy_host,
                 Honeybadger.configuration.proxy_port,
                 Honeybadger.configuration.proxy_user,
                 Honeybadger.configuration.proxy_pass).
                 returns(@http_proxy_class)
          Net::HTTP::Post.expects(:new).with("/v1/deploys").returns(@post)

          @options    = { :environment => "staging", :dry_run => false }
        end

        context "performing a dry run" do
          setup { @output = HoneybadgerTasks.deploy(@options.merge(:dry_run => true)) }

          should "return true without performing any actual request" do
            assert_equal true, @output
            assert_received(@http_proxy, :request) do |expects|
              expects.never
            end
          end
        end

        context "on deploy(options)" do
          setup do
            @output = HoneybadgerTasks.deploy(@options)
          end

          before_should "post to https://api.honeybadger.io:443/v1/deploys" do
            @http_proxy_class.expects(:new).with("api.honeybadger.io", 443).returns(@http_proxy)
            @post.expects(:set_form_data).with(kind_of(Hash))
            @http_proxy.expects(:request).with(any_parameters).returns(successful_response)
          end

          before_should "use send the environment param" do
            @post.expects(:set_form_data).
              with(has_entries("deploy[environment]" => "staging"))
          end

          [:local_username, :repository, :revision].each do |key|
            before_should "use send the #{key} param if it's passed in." do
              @options[key] = "value"
              @post.expects(:set_form_data).
                with(has_entries("deploy[#{key}]" => "value"))
            end
          end

          before_should "puts the response body on success" do
            HoneybadgerTasks.expects(:puts).with("Succesfully recorded deployment")
            @http_proxy.expects(:request).with(any_parameters).returns(successful_response('body'))
          end

          before_should "puts the response body on failure" do
            HoneybadgerTasks.expects(:puts).with("body")
            @http_proxy.expects(:request).with(any_parameters).returns(unsuccessful_response('body'))
          end

          should "return false on failure", :before => lambda {
            @http_proxy.expects(:request).with(any_parameters).returns(unsuccessful_response('body'))
          } do
            assert !@output
          end

          should "return true on success", :before => lambda {
            @http_proxy.expects(:request).with(any_parameters).returns(successful_response('body'))
          } do
            assert @output
          end
        end
      end
    end

    context "in a configured project with custom host" do
      setup do
        Honeybadger.configure do |config|
          config.api_key = "1234123412341234"
          config.host = "custom.host"
          config.secure = false
        end
      end

      context "on deploy(:environment => 'staging')" do
        setup { @output = HoneybadgerTasks.deploy(:environment => "staging") }

        before_should "post to the custom host" do
          @post             = stub("post",     :set_form_data => nil)
          @http_proxy       = stub("proxy",    :request => @response)

          @post.stubs(:[]=).with('X-API-Key', '1234123412341234').returns(true)

          @http_proxy_class = stub("proxy_class", :new => @http_proxy)
          @http_proxy_class.expects(:new).with("custom.host", 80).returns(@http_proxy)
          Net::HTTP.expects(:Proxy).with(any_parameters).returns(@http_proxy_class)
          Net::HTTP::Post.expects(:new).with("/v1/deploys").returns(@post)
          @post.expects(:set_form_data).with(kind_of(Hash))
          @http_proxy.expects(:request).with(any_parameters).returns(successful_response)
        end
      end
    end

    context "when not configured" do
      setup { Honeybadger.configure { |config| config.api_key = "" } }

      context "on deploy(:environment => 'staging')" do
        setup { @output = HoneybadgerTasks.deploy(:environment => "staging") }

        before_should "complain about missing api key" do
          HoneybadgerTasks.expects(:puts).with(regexp_matches(/api key/i))
        end

        should "return false" do
          assert !@output
        end
      end
    end
  end
end
