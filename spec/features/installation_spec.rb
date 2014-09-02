require 'honeybadger/config'

feature "Installing honeybadger via the cli" do
  RSpec.shared_examples "cli installer" do
    let(:config) { Honeybadger::Config.new(:api_key => 'asdf', :'config.path' => config_file) }

    before { set_env('HONEYBADGER_BACKEND', 'debug') }

    it "outputs successful result" do
      assert_cmd('honeybadger install asdf')
      expect(all_output).to match /Writing configuration/i
      expect(all_output).to match /Installation complete/i
      expect(all_output).not_to match /heroku/i
      expect(all_output).not_to match /Starting Honeybadger/i
    end

    it "creates the configuration file" do
      expect { assert_cmd('honeybadger install asdf') }.to change { config_file.exist? }.from(false).to(true)
    end

    it "sends a test notification" do
      set_env('HONEYBADGER_LOGGING_LEVEL', '0')
      assert_cmd('honeybadger install asdf')
      assert_notification('error' => {'class' => 'HoneybadgerTestingException'})
    end

    context "with the --no-test option" do
      it "skips the test notification" do
        set_env('HONEYBADGER_LOGGING_LEVEL', '0')
        assert_cmd('honeybadger install asdf --no-test')
        assert_no_notification
      end
    end

    scenario "when the configuration file already exists" do
      before { config.write }

      it "does not overwrite existing configuration" do
        assert_cmd('honeybadger install asdf')
        expect { assert_cmd('honeybadger install asdf') }.not_to change { config_file.mtime }
      end

      it "outputs successful result" do
        assert_cmd('honeybadger install asdf')
        expect(all_output).to match /Installation complete/i
      end
    end
  end

  scenario "in a standalone project" do
    let(:config_file) { CMD_ROOT.join('honeybadger.yml') }

    it_behaves_like "cli installer"
  end

  scenario "in a Rails project", framework: :rails do
    let(:config_file) { RAILS_ROOT.join('config', 'honeybadger.yml') }

    it_behaves_like "cli installer"
  end

end
