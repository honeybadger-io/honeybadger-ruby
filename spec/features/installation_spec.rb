require 'honeybadger/config'

feature "Installing honeybadger via the cli" do
  shared_examples_for "cli installer" do |expected_output|
    let(:config) { Honeybadger::Config.new(:api_key => 'asdf', :'config.path' => config_file) }

    before { set_environment_variable('HONEYBADGER_BACKEND', 'debug') }

    it "outputs successful result" do
      expect(run('honeybadger install asdf')).to be_successfully_executed
      expect(all_output).to match /Writing configuration/i
      expect(all_output).to match /Installation complete/i
      expect(all_output).not_to match /heroku/i
      expect(all_output).not_to match /Starting Honeybadger/i
      expect(all_output).to match /#{expected_output}/i
    end

    it "creates the configuration file" do
      expect {
        run_simple('honeybadger install asdf', fail_on_error: true)
      }.to change { config_file.exist? }.from(false).to(true)
    end

    it "sends a test notification" do
      set_environment_variable('HONEYBADGER_LOGGING_LEVEL', '1')
      expect(run('honeybadger install asdf')).to be_successfully_executed
      assert_notification('error' => {'class' => 'HoneybadgerTestingException'})
    end

    context "with the --no-test option" do
      it "skips the test notification" do
        set_environment_variable('HONEYBADGER_LOGGING_LEVEL', '1')
        expect(run('honeybadger install asdf --no-test')).to be_successfully_executed
        assert_no_notification
      end
    end

    scenario "when the configuration file already exists" do
      before { config.write }

      it "does not overwrite existing configuration" do
        expect(run('honeybadger install asdf')).to be_successfully_executed
        expect {
          run_simple('honeybadger install asdf', fail_on_error: true)
        }.not_to change { config_file.mtime }
      end

      it "outputs successful result" do
        expect(run('honeybadger install asdf')).to be_successfully_executed
        expect(all_output).to match /Installation complete/i
      end
    end

    scenario "when capistrano is detected" do
      let(:capfile) { CMD_ROOT.join('Capfile') }

      before do
        capify
      end

      it "installs capistrano command" do
        expect(run('honeybadger install asdf')).to be_successfully_executed
        expect(run('bundle exec cap -T')).to be_successfully_executed
        expect(all_output).to match(/honeybadger\:deploy/i)
      end
    end
  end

  scenario "in a standalone project" do
    let(:config_file) { CMD_ROOT.join('honeybadger.yml') }

    it_behaves_like "cli installer", "Rails was not detected"
  end

  scenario "in a Rails project", framework: :rails do
    let(:config_file) { RAILS_ROOT.join('config', 'honeybadger.yml') }

    it_behaves_like "cli installer", "Detected rails"
  end

end
