require 'honeybadger'

feature "Running the check_ins cli command" do
  scenario "sync check ins" do
    context "with config file" do
      let(:config_file_contents) { 
        {
          checkins: [
            {
              project_id: 'abcd',
              name: "worker check in",
              schedule_type: "simple",
              report_period: "1 hour"
            }
          ] 
        }.to_yaml
      }
      let(:config_file) { TMP_DIR.join("honeybadger.yml") }
      before { 
        File.write(config_file, config_file_contents)
        set_environment_variable('HONEYBADGER_CONFIG_PATH', config_file)
        set_environment_variable('HONEYBADGER_PERSONAL_AUTH_TOKEN', 'asdf')
        set_environment_variable('HONEYBADGER_BACKEND', 'test')
      }

      after { File.unlink(config_file) }

      it "syncs check in configuration" do
        expect(run_command("honeybadger sync_checkins --personal-auth-token=abcd")).to be_successfully_executed
      end
    end

    context "with config file without checkins" do
      let(:config_file_contents) { 
        {
        }.to_yaml
      }
      let(:config_file) { TMP_DIR.join("honeybadger.yml") }
      before { 
        File.write(config_file, config_file_contents)
        set_environment_variable('HONEYBADGER_CONFIG_PATH', config_file)
        set_environment_variable('HONEYBADGER_PERSONAL_AUTH_TOKEN', 'asdf')
        set_environment_variable('HONEYBADGER_BACKEND', 'test')
      }

      after { File.unlink(config_file) }

      it "does not sync check_in configuration if checkins are not configured in config file" do
        expect(run_command("honeybadger sync_checkins --personal-auth-token=abcd")).to_not be_successfully_executed
        expect(all_output).to match(/No checkins provided in config file/)
      end
    end
  end
end
 