require "honeybadger/config"
require "pathname"

RSpec.describe "Installing honeybadger via the cli", type: :aruba do
  shared_examples_for "cli installer" do |rails|
    let(:config) { Honeybadger::Config.new(api_key: "asdf", "config.path": config_file) }

    before { set_environment_variable("HONEYBADGER_BACKEND", "debug") }

    it "outputs successful result" do
      expect(run_command("honeybadger install asdf")).to be_successfully_executed
      expect(all_output).to match(/Writing configuration/i)
      expect(all_output).to match(/Happy 'badgering/i)
      expect(all_output).not_to match(/heroku/i)
      expect(all_output).not_to match(/Starting Honeybadger/i)
      if rails
        expect(all_output).to match(/Detected Rails/i)
      else
        expect(all_output).not_to match(/Detected Rails/i)
      end
    end

    it "creates the configuration file" do
      expect {
        run_command_and_stop("honeybadger install asdf", fail_on_error: true)
      }.to change { config_file.exist? }.from(false).to(true)
    end

    it "sends a test notification" do
      set_environment_variable("HONEYBADGER_LOGGING_LEVEL", "1")
      expect(run_command("honeybadger install asdf")).to be_successfully_executed
      assert_notification("error" => {"class" => "HoneybadgerTestingException"})
    end

    context "with the --no-test option" do
      it "skips the test notification" do
        set_environment_variable("HONEYBADGER_LOGGING_LEVEL", "1")
        expect(run_command("honeybadger install asdf --no-test")).to be_successfully_executed
        assert_no_notification
      end
    end

    context "with the insights flag" do
      it "enables insights" do
        run_command_and_stop("honeybadger install asdf --insights", fail_on_error: true)
        expect(YAML.load_file(config_file).dig("insights", "enabled")).to eq(true)
      end

      it "disables insights" do
        run_command_and_stop("honeybadger install asdf --no-insights", fail_on_error: true)
        expect(YAML.load_file(config_file).dig("insights", "enabled")).to eq(false)
      end

      it "defaults to enabled" do
        run_command_and_stop("honeybadger install asdf", fail_on_error: true)
        expect(YAML.load_file(config_file).dig("insights", "enabled")).to eq(true)
      end
    end

    context "with host and/or UI host flags" do
      let(:yaml) { YAML.load_file(config_file) }

      it "configures the host" do
        run_command_and_stop("honeybadger install asdf --host api.honeybadger.io", fail_on_error: true)
        expect(yaml.dig("connection", "host")).to eq("api.honeybadger.io")
      end

      it "configures the UI host" do
        run_command_and_stop("honeybadger install asdf --ui_host app.honeybadger.io", fail_on_error: true)
        expect(yaml.dig("connection", "ui_host")).to eq("app.honeybadger.io")
      end

      it "configures both hosts" do
        run_command_and_stop("honeybadger install asdf --host api.honeybadger.io --ui_host app.honeybadger.io", fail_on_error: true)
        expect(yaml.dig("connection", "host")).to eq("api.honeybadger.io")
        expect(yaml.dig("connection", "ui_host")).to eq("app.honeybadger.io")
      end
    end

    context "when the configuration file already exists" do
      before { File.write(config_file, <<~YML) }
        ---
        api_key: 'asdf'
      YML

      it "does not overwrite existing configuration" do
        expect(run_command("honeybadger install asdf")).to be_successfully_executed
        expect {
          run_command_and_stop("honeybadger install asdf", fail_on_error: true)
        }.not_to change { config_file.mtime }
      end

      it "outputs successful result" do
        expect(run_command("honeybadger install asdf")).to be_successfully_executed
        expect(all_output).to match(/Happy 'badgering/i)
      end
    end

    context "when capistrano is detected" do
      let(:capfile) { Pathname(current_dir).join("Capfile") }

      before { File.write(capfile, <<~YML) }
        if respond_to?(:namespace) # cap2 differentiator
          load 'deploy'
        else
          require 'capistrano/setup'
          require 'capistrano/deploy'
        end
      YML

      it "installs capistrano command" do
        expect(run_command("honeybadger install asdf")).to be_successfully_executed
        expect(run_command("bundle exec cap -T")).to be_successfully_executed
        expect(all_output).to match(/honeybadger:deploy/i)
      end
    end
  end

  context "in a plain ruby project" do
    let(:config_file) { Pathname(current_dir).join("honeybadger.yml") }

    it_behaves_like "cli installer", false
  end

  context "in a Rails project", framework: :rails do
    let(:config_file) { Pathname(current_dir).join("config", "honeybadger.yml") }

    it_behaves_like "cli installer", true
  end
end
