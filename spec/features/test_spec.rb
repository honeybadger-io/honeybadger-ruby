require 'honeybadger'

feature "Running the test cli command" do
  scenario "in a standalone project" do
    it "displays expected debug output" do
      set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
      expect(run("honeybadger test")).to be_successfully_executed
      expect(all_output).to match /asdf/
      expect(all_output).to match /Starting Honeybadger/
      expect(all_output).to match /HoneybadgerTestingException/
      # Make sure the worker timeout isn't being exceeded.
      expect(all_output).not_to match /kill/
    end

    context "with invalid configuration" do
      it "displays expected debug output" do
        expect(run("honeybadger test --dry-run")).to be_successfully_executed
        expect(all_output).to match /Unable to start Honeybadger/
        expect(all_output).to match /invalid/
      end
    end

    context "with the --file option" do
      let(:file) { File.join(current_dir, 'debug.txt') }

      after { FileUtils.rm(file) }

      it "saves the debug output to file" do
        expect(run("honeybadger test --file debug.txt")).to be_successfully_executed
        expect(all_output).to match /Output written to debug\.txt/
        expect(File.exist?(file)).to eq true
      end
    end
  end

  scenario "in a rails project", framework: :rails do
    let(:config) { Honeybadger::Config.new(:api_key => 'asdf', :'config.path' => RAILS_ROOT.join('config/honeybadger.yml')) }

    it "displays expected debug output" do
      config.write
      expect(run("honeybadger test")).to be_successfully_executed
      expect(all_output).to match /asdf/
      expect(all_output).to match /Starting Honeybadger/
      expect(all_output).to match /HoneybadgerTestingException/
    end

    context "with invalid configuration" do
      it "displays expected debug output" do
        expect(run("honeybadger test --dry-run")).to be_successfully_executed
        expect(all_output).to match /Unable to start Honeybadger/
        expect(all_output).to match /invalid/
      end
    end
  end
end
