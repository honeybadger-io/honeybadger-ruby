require 'honeybadger'

feature "Running the test cli command" do
  scenario "in a standalone project" do
    it "displays expected debug output and sends notification" do
      set_environment_variable('HONEYBADGER_API_KEY', 'asdf')
      expect(run_command("honeybadger test")).to be_successfully_executed
      expect(all_output).not_to match /Detected Rails/i
      expect(all_output).to match /asdf/
      expect(all_output).to match /Initializing Honeybadger/
      expect(all_output).to match /HoneybadgerTestingException/
      # Make sure the worker timeout isn't being exceeded.
      expect(all_output).not_to match /kill/
      assert_notification('error' => {'class' => 'HoneybadgerTestingException'})
    end

    context "with invalid configuration" do
      it "displays expected debug output" do
        expect(run_command("honeybadger test --dry-run")).not_to be_successfully_executed
        expect(all_output).not_to match /Detected Rails/i
        expect(all_output).to match /API key is missing/i
      end
    end
  end

  scenario "in a rails project", framework: :rails do
    let(:config_file) { Pathname(current_dir).join('config', 'honeybadger.yml') }

    it "displays expected debug output and sends notification" do
      File.write(config_file, <<-YML)
---
api_key: 'asdf'
YML
      expect(run_command("honeybadger test")).to be_successfully_executed
      expect(all_output).to match /Detected Rails/i
      expect(all_output).to match /asdf/
      expect(all_output).to match /Initializing Honeybadger/
      expect(all_output).to match /HoneybadgerTestingException/
      assert_notification('error' => {'class' => 'HoneybadgerTestingException'})
    end

    context "with invalid configuration" do
      it "displays expected debug output" do
        expect(run_command("honeybadger test --dry-run")).not_to be_successfully_executed
        expect(all_output).to match /Detected Rails/i
        expect(all_output).to match /API key is missing/i
      end
    end
  end
end
