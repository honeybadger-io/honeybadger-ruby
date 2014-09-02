require 'honeybadger/config'

feature "Installing honeybadger via the cli" do
  RSpec.shared_examples "cli deployer" do
    let(:config) { Honeybadger::Config.new(:api_key => 'asdf', :'config.path' => config_file) }

    scenario "when the configuration is invalid" do
      it "outputs failed result" do
        expect(cmd('honeybadger deploy -e production', false)).to exit_with(1)
        expect(all_output).not_to match /complete/i
        expect(all_output).to match /invalid/i
      end
    end

    scenario "when the configuration file already exists" do
      before { config.write }

      it "outputs successful result" do
        assert_cmd('honeybadger deploy -e production')
        expect(all_output).to match /complete/i
        expect(all_output).to match /production/i
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
