require 'honeybadger/config'

feature "Installing honeybadger via the cli" do
  shared_examples_for "cli deployer" do
    let(:config) { Honeybadger::Config.new(:api_key => 'asdf', :'config.path' => config_file) }

    scenario "when the configuration is invalid" do
      it "outputs failed result" do
        expect(run('honeybadger deploy -e production')).not_to be_successfully_executed
        expect(all_output).not_to match /complete/i
        expect(all_output).to match /invalid/i
      end
    end

    scenario "when the configuration file is valid" do
      before { config.write }

      it "outputs successful result" do
        expect(run('honeybadger deploy -e production')).to be_successfully_executed
        expect(all_output).to match /complete/i
        expect(all_output).to match /production/i
      end
    end

    scenario "the request fails" do
      before { config.write }
      before { set_environment_variable('DEBUG_BACKEND_STATUS', '500') }

      it "outputs successful result" do
        expect(run('honeybadger deploy -e production')).not_to be_successfully_executed
        expect(all_output).not_to match /complete/i
        expect(all_output).to match /500/i
      end
    end
  end

  scenario "in a standalone project" do
    let(:config_file) { CMD_ROOT.join('honeybadger.yml') }

    it_behaves_like "cli deployer"
  end

  scenario "in a Rails project", framework: :rails do
    let(:config_file) { RAILS_ROOT.join('config', 'honeybadger.yml') }

    it_behaves_like "cli deployer"
  end

end
