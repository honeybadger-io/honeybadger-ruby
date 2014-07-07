require 'spec_helper'
require 'rubygems'

require File.expand_path('../../lib/honeybadger_tasks', __FILE__)

describe HoneybadgerTasks do
  def successful_response(body = "")
    response = Net::HTTPSuccess.new('1.2', '200', 'OK')
    response.stub(:body).and_return(body)
    response
  end

  def unsuccessful_response(body = "")
    response = Net::HTTPClientError.new('1.2', '200', 'OK')
    response.stub(:body).and_return(body)
    response
  end

  context "being quiet" do
    before do
      HoneybadgerTasks.stub(:puts)
      $stderr.stub(:puts)
    end

    context "in a configured project" do
      before(:each) { Honeybadger.configure { |config| config.api_key = "1234123412341234" } }

      context "on deploy({})" do
        it "complains about missing rails env" do
          $stderr.should_receive(:puts).with(/which environment/i)
          HoneybadgerTasks.deploy({})
        end

        it "return false" do
          expect(HoneybadgerTasks.deploy({})).to be_false
        end
      end

      context "given an optional HTTP proxy and valid options" do
        before(:each) do
          @response         = double("response",    :body => "stub body")
          @http_proxy       = double("proxy",       :request => @response,
                                                  :use_ssl= => nil,
                                                  :ca_file= => nil,
                                                  :verify_mode= => nil)
          @http_proxy_class = double("proxy_class", :new => @http_proxy)
          @post             = double("post",        :set_form_data => nil)

          @post.stub(:[]=).with('X-API-Key', '1234123412341234').and_return(true)

          Net::HTTP.should_receive(:Proxy).
            with(Honeybadger.configuration.proxy_host,
                 Honeybadger.configuration.proxy_port,
                 Honeybadger.configuration.proxy_user,
                 Honeybadger.configuration.proxy_pass).
                 and_return(@http_proxy_class)
          Net::HTTP::Post.should_receive(:new).with("/v1/deploys").and_return(@post)

          @options    = { :environment => "staging", :dry_run => false }
        end

        context "performing a dry run" do
          before(:each) { @output = HoneybadgerTasks.deploy(@options.merge(:dry_run => true)) }

          it "return true without performing any actual request" do
            @http_proxy.should_receive(:request).never
            @output.should be_true
          end
        end

        context "on deploy(options)" do
          it "posts to https://api.honeybadger.io:443/v1/deploys" do
            @http_proxy_class.should_receive(:new).with("api.honeybadger.io", 443).and_return(@http_proxy)
            @post.should_receive(:set_form_data).with(kind_of(Hash))
            @http_proxy.should_receive(:request).with(anything).and_return(successful_response)
            HoneybadgerTasks.deploy(@options)
          end

          it "uses send the environment param" do
            @post.should_receive(:set_form_data).
              with(hash_including("deploy[environment]" => "staging"))
            HoneybadgerTasks.deploy(@options)
          end

          [:local_username, :repository, :revision].each do |key|
            it "uses send the #{key} param if it's passed in." do
              @options[key] = "value"
              @post.should_receive(:set_form_data).
                with(hash_including("deploy[#{key}]" => "value"))
              HoneybadgerTasks.deploy(@options)
            end
          end

          it "puts the response body on success" do
            HoneybadgerTasks.should_receive(:puts).with("Successfully recorded deployment")
            @http_proxy.should_receive(:request).with(anything).and_return(successful_response('body'))
            HoneybadgerTasks.deploy(@options)
          end

          it "puts the response body on failure" do
            $stderr.should_receive(:puts).with(/body/)
            @http_proxy.should_receive(:request).with(anything).and_return(unsuccessful_response('body'))
            HoneybadgerTasks.deploy(@options)
          end

          it "puts the response class on failure" do
            $stderr.should_receive(:puts).with(/Net::HTTPClientError/)
            @http_proxy.should_receive(:request).with(anything).and_return(unsuccessful_response)
            HoneybadgerTasks.deploy(@options)
          end

          it "returns false on failure" do
            @http_proxy.should_receive(:request).with(anything).and_return(unsuccessful_response('body'))
            output = HoneybadgerTasks.deploy(@options)
            expect(output).to be_false
          end

          it "return true on success" do
            @http_proxy.should_receive(:request).with(anything).and_return(successful_response('body'))
            output = HoneybadgerTasks.deploy(@options)
            expect(output).to be_true
          end
        end
      end
    end

    context "in a configured project with custom host" do
      before(:each) do
        Honeybadger.configure do |config|
          config.api_key = "1234123412341234"
          config.host = "custom.host"
          config.secure = false
        end
      end

      context "on deploy(:environment => 'staging')" do
        it "posts to the custom host" do
          @post             = double("post",     :set_form_data => nil)
          @http_proxy       = double("proxy",    :request => @response)

          @post.stub(:[]=).with('X-API-Key', '1234123412341234').and_return(true)

          @http_proxy_class = double("proxy_class", :new => @http_proxy)
          @http_proxy_class.should_receive(:new).with("custom.host", 80).and_return(@http_proxy)
          Net::HTTP.should_receive(:Proxy).with(any_args).and_return(@http_proxy_class)
          Net::HTTP::Post.should_receive(:new).with("/v1/deploys").and_return(@post)
          @post.should_receive(:set_form_data).with(kind_of(Hash))
          @http_proxy.should_receive(:request).with(any_args).and_return(successful_response)

          HoneybadgerTasks.deploy(:environment => "staging")
        end
      end
    end

    context "when not configured" do
      before(:each) { Honeybadger.configure { |config| config.api_key = "" } }

      context "on deploy(:environment => 'staging')" do
        it "complains about missing api key" do
          $stderr.should_receive(:puts).with(/api key/i)
          HoneybadgerTasks.deploy(:environment => "staging")
        end

        it "return false" do
          @output = HoneybadgerTasks.deploy(:environment => "staging")
          @output.should be_false
        end
      end
    end
  end
end
