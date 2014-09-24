require 'honeybadger'

feature "Running the debug cli command" do
  scenario "in a standalone project" do
    before { set_env('HONEYBADGER_API_KEY', 'asdf') }

    it "displays expected debug output" do
      assert_cmd("honeybadger debug")
      expect(all_output).to match /asdf/
      expect(all_output).to match /Starting Honeybadger/
      expect(all_output).not_to match /HoneybadgerTestingException/
    end

    context "with the test option" do
      it "starts Honeybadger and performs the test" do
        assert_cmd("honeybadger debug --test")
        expect(all_output).to match /Starting Honeybadger/
        expect(all_output).to match /HoneybadgerTestingException/
      end

      context "with invalid configuration" do
        before { restore_env }

        it "displays expected debug output" do
          assert_cmd("honeybadger debug --test")
          expect(all_output).to match /Unable to start Honeybadger/
          expect(all_output).to match /invalid/
        end
      end
    end

    context "with the --file option" do
      let(:file) { File.join(current_dir, 'debug.txt') }

      after do
        FileUtils.rm(file)
      end

      context "and valid config" do
        before { set_env('HONEYBADGER_API_KEY', 'asdf') }

        it "saves the debug output to file" do
          assert_cmd("honeybadger debug --file debug.txt")
          expect(all_output).to match /Output written to debug\.txt/
          expect(File.exist?(file)).to eq true
        end
      end

      context "and invalid config" do
        it "saves the debug output to file" do
          assert_cmd("honeybadger debug --file debug.txt")
          expect(all_output).to match /Output written to debug\.txt/
          expect(File.exist?(file)).to eq true
        end
      end
    end
  end

  scenario "in a rails project", framework: :rails do
    let(:config) { Honeybadger::Config.new(:api_key => 'asdf', :'config.path' => RAILS_ROOT.join('config/honeybadger.yml')) }

    before do
      config.write
    end

    it "displays expected debug output" do
      assert_cmd("honeybadger debug")
      expect(all_output).to match /asdf/
      expect(all_output).to match /Starting Honeybadger/
      expect(all_output).not_to match /HoneybadgerTestingException/
    end

    context "with the test option" do
      it "starts Honeybadger and performs the test" do
        assert_cmd("honeybadger debug --test")
        expect(all_output).to match /Starting Honeybadger/
        expect(all_output).to match /HoneybadgerTestingException/
      end

      context "with invalid configuration" do
        before { config.config_path.delete }

        it "displays expected debug output" do
          assert_cmd("honeybadger debug --test")
          expect(all_output).to match /Unable to start Honeybadger/
          expect(all_output).to match /invalid/
        end
      end
    end
  end
end
