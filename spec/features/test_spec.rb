# require 'honeybadger'

feature "Running the test cli command" do
  scenario "in a standalone project" do
    it "displays expected debug output and sends notification" do
      set_environment_variable('HONEYBADGER_API_KEY', 'asdf')

      cmd = run_command("honeybadger test")
      expect(cmd).to be_successfully_executed
      expect(cmd.output).not_to match /Detected Rails/i
      expect(cmd.output).to match /asdf/
      expect(cmd.output).to match /Initializing Honeybadger/
      expect(cmd.output).to match /HoneybadgerTestingException/
      # Make sure the worker timeout isn't being exceeded.
      expect(cmd.output).not_to match /kill/
      assert_notification(cmd.output, 'error' => {'class' => 'HoneybadgerTestingException'})

      set_environment_variable('HONEYBADGER_API_KEY', nil)
    end

    context "with invalid configuration" do
      it "displays expected debug output" do
        cmd = run_command("honeybadger test --dry-run")
        expect(cmd).not_to be_successfully_executed
        expect(cmd.output).not_to match /Detected Rails/i
        expect(cmd.output).to match /API key is missing/i
      end
    end
  end

  scenario "in a rails project", framework: :rails do
    let(:config_file) { Pathname(FEATURES_DIR).join('config', 'honeybadger.yml') }

    it "displays expected debug output and sends notification" do
      File.write(config_file, <<-YML)
---
api_key: 'asdf'
YML
      cmd = run_command("honeybadger test")
      expect(cmd).to be_successfully_executed
      expect(cmd.output).to match /Detected Rails/i
      expect(cmd.output).to match /asdf/
      expect(cmd.output).to match /Initializing Honeybadger/
      expect(cmd.output).to match /HoneybadgerTestingException/
      assert_notification(cmd.output, 'error' => {'class' => 'HoneybadgerTestingException'})
    end

    context "with invalid configuration" do
      it "displays expected debug output" do
        cmd = run_command("honeybadger test --dry-run")
        expect(cmd).not_to be_successfully_executed
        expect(cmd.output).to match /Detected Rails/i
        expect(cmd.output).to match /API key is missing/i
      end
    end
  end
end
